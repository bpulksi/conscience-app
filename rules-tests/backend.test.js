// Runs the backend logic with the real Admin SDK against the Firestore emulator.
// The tests in functions/ use an in-memory fake, so this catches anything the
// fake gets wrong: real transactions, queries and field deletes.
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { createRequire } = require("node:module");
const { resolve } = require("node:path");
const { test } = require("node:test");

const fromFunctions = createRequire(resolve(__dirname, "../functions/package.json"));
const { getApps, initializeApp } = fromFunctions("firebase-admin/app");
const { getFirestore } = fromFunctions("firebase-admin/firestore");
const coins = require("../functions/lib/coins.js");
const partner = require("../functions/lib/partner.js");
const { createUserProfile } = require("../functions/lib/users.js");

assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Run through the emulator: npm test");
if (getApps().length === 0) initializeApp({ projectId: "demo-conscience" });
const db = getFirestore();

const MINUTE = 60 * 1000;

function setup() {
  const clock = { ms: Date.UTC(2026, 10, 5, 12) };
  const pushes = [];
  const deps = {
    db,
    now: () => clock.ms,
    sendPush: async (message) => void pushes.push(message),
  };
  return { deps, pushes, advance: (ms) => void (clock.ms += ms) };
}

async function newUser(deps, fields = {}) {
  const uid = `u${randomUUID().replaceAll("-", "")}`;
  await createUserProfile(deps, uid, "Test User");
  if (Object.keys(fields).length) await db.doc(`users/${uid}`).update(fields);
  return uid;
}

const user = async (uid) => (await db.doc(`users/${uid}`).get()).data();

async function rejectsWith(call, code) {
  await assert.rejects(call, (e) => {
    assert.equal(e.code, code);
    return true;
  });
}

async function linkedPair(deps) {
  const [a, b] = [await newUser(deps), await newUser(deps)];
  const { code } = await partner.createInviteCode(deps, b);
  await partner.linkAccountabilityPartner(deps, a, { inviteCode: code });
  return [a, b];
}

test("a repeated sign-up event keeps the existing profile", async () => {
  const { deps } = setup();
  const uid = await newUser(deps, { focusCoins: 40 });
  await createUserProfile(deps, uid, "Test User");
  assert.equal((await user(uid)).focusCoins, 40);
});

test("a wellness session pays out and clears the active session", async () => {
  const { deps, advance } = setup();
  const uid = await newUser(deps);
  const { sessionToken } = await coins.startWellnessSession(deps, uid, { sessionType: "meditation" });

  await rejectsWith(coins.claimWellnessReward(deps, uid, { sessionToken }), "failed-precondition");
  advance(10 * MINUTE);
  assert.deepEqual(await coins.claimWellnessReward(deps, uid, { sessionToken }), { coinsAwarded: 50 });

  const profile = await user(uid);
  assert.equal(profile.focusCoins, 50);
  assert.equal("activeWellnessToken" in profile, false);
  await rejectsWith(coins.claimWellnessReward(deps, uid, { sessionToken }), "already-exists");
});

test("simultaneous claims pay out once on real transactions", async () => {
  const { deps, advance } = setup();
  const uid = await newUser(deps);
  const { sessionToken } = await coins.startWellnessSession(deps, uid, { sessionType: "yoga" });
  advance(15 * MINUTE);

  const results = await Promise.allSettled(
    Array.from({ length: 8 }, () => coins.claimWellnessReward(deps, uid, { sessionToken }))
  );

  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal((await user(uid)).focusCoins, 75);
});

test("a new invite code revokes the old one, and links can't be overwritten", async () => {
  const { deps } = setup();
  const [a, b, c] = [await newUser(deps), await newUser(deps), await newUser(deps)];

  const first = await partner.createInviteCode(deps, b);
  const second = await partner.createInviteCode(deps, b);
  await rejectsWith(partner.linkAccountabilityPartner(deps, a, { inviteCode: first.code }), "not-found");
  await partner.linkAccountabilityPartner(deps, a, { inviteCode: second.code });

  assert.equal((await user(a)).accountabilityPartner, b);
  assert.equal((await user(b)).accountabilityPartner, a);
  await rejectsWith(partner.createInviteCode(deps, b), "failed-precondition");
  await rejectsWith(partner.linkAccountabilityPartner(deps, c, { inviteCode: second.code }), "already-exists");

  await partner.unlinkAccountabilityPartner(deps, a);
  assert.equal("accountabilityPartner" in (await user(a)), false);
  assert.equal("accountabilityPartner" in (await user(b)), false);
});

test("the full extension flow works, and the daily budget holds", async () => {
  const { deps, pushes } = setup();
  const [a, b] = await linkedPair(deps);
  await db.doc(`users/${b}`).update({ fcmToken: "partner-device" });

  const { requestId } = await partner.requestExtension(deps, a);
  assert.equal(pushes.at(-1).token, "partner-device");
  await rejectsWith(partner.requestExtension(deps, a), "already-exists");
  await rejectsWith(partner.respondToExtension(deps, a, { requestId, approved: true }), "permission-denied");

  await partner.respondToExtension(deps, b, { requestId, approved: true });
  assert.equal((await db.doc(`extensionRequests/${requestId}`).get()).data().status, "approved");

  const second = await partner.requestExtension(deps, a);
  await partner.respondToExtension(deps, b, { requestId: second.requestId, approved: true });
  await rejectsWith(partner.requestExtension(deps, a), "resource-exhausted");
});

test("simultaneous approvals can't exceed the budget on real transactions", async () => {
  const { deps } = setup();
  const [a, b] = await linkedPair(deps);

  const ids = [];
  for (let i = 0; i < 5; i++) {
    const ref = db.collection("extensionRequests").doc();
    await ref.set({ requesterId: a, partnerId: b, status: "pending", expiresAt: deps.now() + 60000 });
    ids.push(ref.id);
  }

  const results = await Promise.allSettled(
    ids.map((requestId) => partner.respondToExtension(deps, b, { requestId, approved: true }))
  );

  assert.equal(results.filter((r) => r.status === "fulfilled").length, partner.MAX_DAILY_APPROVALS);
});

test("an expired request is saved as expired", async () => {
  const { deps, advance } = setup();
  const [a, b] = await linkedPair(deps);
  const { requestId } = await partner.requestExtension(deps, a);
  advance(partner.REQUEST_TTL_MS + 1);

  await rejectsWith(partner.respondToExtension(deps, b, { requestId, approved: true }), "deadline-exceeded");
  assert.equal((await db.doc(`extensionRequests/${requestId}`).get()).data().status, "expired");
});
