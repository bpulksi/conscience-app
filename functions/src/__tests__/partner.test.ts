import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createInviteCode,
  INVITE_TTL_MS,
  linkAccountabilityPartner,
  MAX_DAILY_APPROVALS,
  REQUEST_TTL_MS,
  requestExtension,
  respondToExtension,
  unlinkAccountabilityPartner,
} from "../partner";
import { Deps } from "../deps";
import { MINUTE, rejectsWith, setup } from "./harness";

async function link(deps: Deps, a: string, b: string) {
  const { code } = await createInviteCode(deps, a);
  await linkAccountabilityPartner(deps, b, { inviteCode: code });
}

function linked() {
  const ctx = setup(["alice", "bob", "mallory"]);
  return { ...ctx, ready: link(ctx.deps, "bob", "alice") };
}

// ── Invites ──────────────────────────────────────────────────────────────────

test("linking connects both users", async () => {
  const { deps, fake } = setup();
  const { code } = await createInviteCode(deps, "bob");
  assert.match(code, /^[A-Z2-9]{8}$/);

  await linkAccountabilityPartner(deps, "alice", { inviteCode: ` ${code.toLowerCase()} ` });

  assert.equal(fake.read("users/alice")?.accountabilityPartner, "bob");
  assert.equal(fake.read("users/bob")?.accountabilityPartner, "alice");
  assert.equal(fake.read(`inviteCodes/${code}`)?.used, true);
});

test("invite codes are random, and a new one revokes the old one", async () => {
  const { deps } = setup();
  const first = await createInviteCode(deps, "bob");
  const second = await createInviteCode(deps, "bob");
  assert.notEqual(first.code, second.code);

  await rejectsWith(linkAccountabilityPartner(deps, "alice", { inviteCode: first.code }), "not-found");
  await linkAccountabilityPartner(deps, "alice", { inviteCode: second.code });
});

test("an existing partnership can't be overwritten by a new link", async () => {
  const { deps, fake, ready } = linked();
  await ready;

  // A code from before the partnership, held by a linked user.
  fake.seed("inviteCodes/OLDCODE2", { uid: "bob", used: false, expiresAt: deps.now() + INVITE_TTL_MS });
  await rejectsWith(linkAccountabilityPartner(deps, "mallory", { inviteCode: "OLDCODE2" }), "failed-precondition");

  assert.equal(fake.read("users/bob")?.accountabilityPartner, "alice");
  assert.equal(fake.read("users/mallory")?.accountabilityPartner, undefined);
});

test("expired, used, unknown and self-issued codes are rejected", async () => {
  const { deps, advance } = setup(["alice", "bob", "carol"]);

  const self = await createInviteCode(deps, "alice");
  await rejectsWith(linkAccountabilityPartner(deps, "alice", { inviteCode: self.code }), "invalid-argument");
  await rejectsWith(linkAccountabilityPartner(deps, "alice", { inviteCode: "NOSUCHAA" }), "not-found");
  await rejectsWith(linkAccountabilityPartner(deps, "alice", { inviteCode: "a/b" }), "invalid-argument");

  const stale = await createInviteCode(deps, "bob");
  advance(INVITE_TTL_MS + 1);
  await rejectsWith(linkAccountabilityPartner(deps, "alice", { inviteCode: stale.code }), "deadline-exceeded");

  const fresh = await createInviteCode(deps, "bob");
  await linkAccountabilityPartner(deps, "alice", { inviteCode: fresh.code });
  await unlinkAccountabilityPartner(deps, "alice");
  await rejectsWith(linkAccountabilityPartner(deps, "carol", { inviteCode: fresh.code }), "already-exists");
});

test("two people racing for one code: only one links", async () => {
  const { deps, fake } = setup(["alice", "bob", "carol"]);
  const { code } = await createInviteCode(deps, "bob");

  const results = await Promise.allSettled([
    linkAccountabilityPartner(deps, "alice", { inviteCode: code }),
    linkAccountabilityPartner(deps, "carol", { inviteCode: code }),
  ]);

  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const winner = fake.read("users/bob")?.accountabilityPartner;
  const loser = winner === "alice" ? "carol" : "alice";
  assert.equal(fake.read(`users/${winner}`)?.accountabilityPartner, "bob");
  assert.equal(fake.read(`users/${loser}`)?.accountabilityPartner, undefined);
});

test("a user with a partner can't create a code, and can after unlinking", async () => {
  const { deps, fake, ready } = linked();
  await ready;
  await rejectsWith(createInviteCode(deps, "alice"), "failed-precondition");

  await unlinkAccountabilityPartner(deps, "alice");
  assert.equal(fake.read("users/alice")?.accountabilityPartner, undefined);
  assert.equal(fake.read("users/bob")?.accountabilityPartner, undefined);
  await createInviteCode(deps, "alice");
});

test("unlink is safe with no partner", async () => {
  const { deps } = setup();
  assert.deepEqual(await unlinkAccountabilityPartner(deps, "alice"), { success: true });
});

// ── Extension requests ───────────────────────────────────────────────────────

test("request and approval notify the right people", async () => {
  const { deps, fake, pushes, ready } = linked();
  await ready;
  fake.seed("users/alice", { ...fake.read("users/alice"), fcmToken: "alice-device" });
  fake.seed("users/bob", { ...fake.read("users/bob"), fcmToken: "bob-device" });

  const { requestId } = await requestExtension(deps, "alice");
  assert.equal(pushes[0].token, "bob-device");
  assert.equal(pushes[0].data.requestId, requestId);

  assert.deepEqual(await respondToExtension(deps, "bob", { requestId, approved: true }), { status: "approved" });
  assert.equal(fake.read(`extensionRequests/${requestId}`)?.status, "approved");
  assert.equal(pushes[1].token, "alice-device");
});

test("a failed push doesn't fail the request", async () => {
  const { deps, fake, ready } = linked();
  await ready;
  fake.seed("users/bob", { ...fake.read("users/bob"), fcmToken: "bob-device" });
  const failing: Deps = { ...deps, sendPush: async () => { throw new Error("fcm down"); } };

  const { requestId } = await requestExtension(failing, "alice");
  assert.equal(fake.read(`extensionRequests/${requestId}`)?.status, "pending");
});

test("nobody but the named partner can answer, including the requester", async () => {
  const { deps, fake, ready } = linked();
  await ready;
  const { requestId } = await requestExtension(deps, "alice");

  await rejectsWith(respondToExtension(deps, "alice", { requestId, approved: true }), "permission-denied");
  await rejectsWith(respondToExtension(deps, "mallory", { requestId, approved: true }), "permission-denied");
  assert.equal(fake.read(`extensionRequests/${requestId}`)?.status, "pending");
});

test("the daily approval budget is enforced", async () => {
  const { deps, fake, advance, ready } = linked();
  await ready;

  for (let i = 0; i < MAX_DAILY_APPROVALS; i++) {
    const { requestId } = await requestExtension(deps, "alice");
    await respondToExtension(deps, "bob", { requestId, approved: true });
  }
  await rejectsWith(requestExtension(deps, "alice"), "resource-exhausted");

  advance(24 * 60 * MINUTE);
  const { requestId } = await requestExtension(deps, "alice");
  await respondToExtension(deps, "bob", { requestId, approved: true });
  assert.equal(fake.read(`extensionRequests/${requestId}`)?.status, "approved");
});

test("simultaneous approvals can't exceed the budget", async () => {
  const { deps, fake, ready } = linked();
  await ready;

  const ids: string[] = [];
  for (let i = 0; i < MAX_DAILY_APPROVALS + 2; i++) {
    const id = `req${i}`;
    fake.seed(`extensionRequests/${id}`, {
      requesterId: "alice", partnerId: "bob", status: "pending", expiresAt: deps.now() + REQUEST_TTL_MS,
    });
    ids.push(id);
  }

  const results = await Promise.allSettled(
    ids.map((requestId) => respondToExtension(deps, "bob", { requestId, approved: true }))
  );

  assert.equal(results.filter((r) => r.status === "fulfilled").length, MAX_DAILY_APPROVALS);
});

test("denying doesn't use budget", async () => {
  const { deps, fake, ready } = linked();
  await ready;
  const { requestId } = await requestExtension(deps, "alice");

  assert.deepEqual(await respondToExtension(deps, "bob", { requestId, approved: false }), { status: "denied" });
  assert.equal([...fake.docs.keys()].some((path) => path.startsWith("approvalBudgets/")), false);
});

test("an expired request can't be approved and is marked expired", async () => {
  const { deps, fake, advance, ready } = linked();
  await ready;
  const { requestId } = await requestExtension(deps, "alice");
  advance(REQUEST_TTL_MS + 1);

  await rejectsWith(respondToExtension(deps, "bob", { requestId, approved: true }), "deadline-exceeded");
  assert.equal(fake.read(`extensionRequests/${requestId}`)?.status, "expired");
});

test("only one request can be pending, and it can be answered once", async () => {
  const { deps, advance, ready } = linked();
  await ready;
  const { requestId } = await requestExtension(deps, "alice");
  await rejectsWith(requestExtension(deps, "alice"), "already-exists");

  await respondToExtension(deps, "bob", { requestId, approved: false });
  await rejectsWith(respondToExtension(deps, "bob", { requestId, approved: true }), "failed-precondition");

  const second = await requestExtension(deps, "alice");
  advance(REQUEST_TTL_MS + 1);
  assert.notEqual((await requestExtension(deps, "alice")).requestId, second.requestId);
});

test("a pending request can't be approved after unlinking", async () => {
  const { deps, ready } = linked();
  await ready;
  const { requestId } = await requestExtension(deps, "alice");
  await unlinkAccountabilityPartner(deps, "bob");

  await rejectsWith(respondToExtension(deps, "bob", { requestId, approved: true }), "failed-precondition");
});

test("requests need a partner and responses need valid input", async () => {
  const { deps } = setup();
  await rejectsWith(requestExtension(deps, "alice"), "not-found");
  await rejectsWith(respondToExtension(deps, "bob", { requestId: "x", approved: "yes" }), "invalid-argument");
  await rejectsWith(respondToExtension(deps, "bob", { requestId: "a/b", approved: true }), "invalid-argument");
  await rejectsWith(respondToExtension(deps, "bob", { requestId: "missing", approved: true }), "not-found");
});
