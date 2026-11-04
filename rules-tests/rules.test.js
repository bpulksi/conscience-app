// Checks firestore.rules against the real rules engine in the emulator.
// Set RULES_PATH to test a different rules file.
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { after, before, beforeEach, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");

let env;

const as = (uid) => env.authenticatedContext(uid).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-conscience-rules",
    firestore: {
      rules: readFileSync(process.env.RULES_PATH ?? resolve(__dirname, "../firestore.rules"), "utf8"),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/alice"), { displayName: "Alice", focusCoins: 10, avatarMood: "ZEN", accountabilityPartner: "bob" });
    await setDoc(doc(db, "users/bob"), { displayName: "Bob", focusCoins: 0, accountabilityPartner: "alice" });
    await setDoc(doc(db, "extensionRequests/req1"), { requesterId: "alice", partnerId: "bob", status: "pending", expiresAt: 1 });
    await setDoc(doc(db, "wellnessTokens/tok1"), { uid: "alice", sessionType: "yoga", claimed: false });
    await setDoc(doc(db, "inviteCodes/CODE2345"), { uid: "bob", used: false, expiresAt: 1 });
    await setDoc(doc(db, "approvalBudgets/bob_2026-11-05"), { count: 1 });
    await setDoc(doc(db, "usageStats/alice/daily/2026-11-05"), { totalViceMinutes: 5 });
  });
});

// ── users ────────────────────────────────────────────────────────────────────

test("users can read their own profile, and nobody else's", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "users/alice")));
  await assertFails(getDoc(doc(as("bob"), "users/alice")));
  await assertFails(getDoc(doc(as("mallory"), "users/alice")));
  await assertFails(getDoc(doc(anonymous(), "users/alice")));
  await assertFails(getDocs(collection(as("alice"), "users")));
});

test("users can change their own settings", async () => {
  await assertSucceeds(updateDoc(doc(as("alice"), "users/alice"), {
    displayName: "Al",
    fcmToken: "device-token",
    toughLove: false,
    dailyLimitMinutes: 30,
    viceApps: ["com.instagram.android"],
  }));
  await assertFails(updateDoc(doc(as("mallory"), "users/alice"), { displayName: "Hacked" }));
});

test("users can't give themselves coins", async () => {
  await assertFails(updateDoc(doc(as("alice"), "users/alice"), { focusCoins: 999999 }));
  await assertFails(updateDoc(doc(as("alice"), "users/alice"), { displayName: "Al", focusCoins: 999999 }));
  await assertFails(setDoc(doc(as("alice"), "users/alice"), { displayName: "Al", focusCoins: 999999 }));
});

test("users can't change server-owned fields", async () => {
  for (const change of [
    { accountabilityPartner: "mallory" },
    { avatarMood: "FURIOUS" },
    { activeWellnessToken: "tok1" },
    { lastWellnessAt: 1 },
    { unknownField: true },
  ]) {
    await assertFails(updateDoc(doc(as("alice"), "users/alice"), change));
  }
});

test("users can't create or delete profiles", async () => {
  await assertFails(setDoc(doc(as("newbie"), "users/newbie"), { focusCoins: 500 }));
  await assertFails(setDoc(doc(as("newbie"), "users/newbie"), { displayName: "New" }));
  await assertFails(deleteDoc(doc(as("alice"), "users/alice")));
});

test("display names must be short strings or null", async () => {
  const alice = doc(as("alice"), "users/alice");
  await assertSucceeds(updateDoc(alice, { displayName: "x".repeat(50) }));
  await assertSucceeds(updateDoc(alice, { displayName: null }));
  await assertFails(updateDoc(alice, { displayName: "x".repeat(51) }));
  await assertFails(updateDoc(alice, { displayName: 42 }));
});

// ── extensionRequests ────────────────────────────────────────────────────────

test("only the two people involved can read a request", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "extensionRequests/req1")));
  await assertSucceeds(getDoc(doc(as("bob"), "extensionRequests/req1")));
  await assertFails(getDoc(doc(as("mallory"), "extensionRequests/req1")));
  await assertFails(getDoc(doc(anonymous(), "extensionRequests/req1")));
});

test("the app's incoming-requests query works, but listing everything doesn't", async () => {
  const incoming = (db, uid) =>
    query(collection(db, "extensionRequests"), where("partnerId", "==", uid), where("status", "==", "pending"));

  await assertSucceeds(getDocs(incoming(as("bob"), "bob")));
  await assertFails(getDocs(incoming(as("mallory"), "bob")));
  await assertFails(getDocs(collection(as("bob"), "extensionRequests")));
});

test("clients can't create or answer requests directly", async () => {
  const fake = { requesterId: "alice", partnerId: "alice", status: "approved", expiresAt: 9e15 };
  await assertFails(setDoc(doc(as("alice"), "extensionRequests/selfApproved"), fake));
  await assertFails(updateDoc(doc(as("alice"), "extensionRequests/req1"), { status: "approved" }));
  await assertFails(updateDoc(doc(as("bob"), "extensionRequests/req1"), { status: "approved" }));
  await assertFails(deleteDoc(doc(as("bob"), "extensionRequests/req1")));
});

// ── wellnessTokens ───────────────────────────────────────────────────────────

test("clients can't forge or alter wellness sessions", async () => {
  await assertFails(setDoc(doc(as("alice"), "wellnessTokens/forged"), { uid: "alice", sessionType: "yoga", claimed: false }));
  await assertFails(setDoc(doc(as("alice"), "wellnessTokens/backdated"), { uid: "alice", sessionType: "yoga", issuedAt: new Date(0), claimed: false }));
  await assertFails(updateDoc(doc(as("alice"), "wellnessTokens/tok1"), { claimed: false, issuedAt: new Date(0) }));
  await assertFails(deleteDoc(doc(as("alice"), "wellnessTokens/tok1")));
});

test("only the owner can read a wellness session", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "wellnessTokens/tok1")));
  await assertFails(getDoc(doc(as("mallory"), "wellnessTokens/tok1")));
});

// ── inviteCodes and approvalBudgets ──────────────────────────────────────────

test("invite codes can't be listed, read or forged", async () => {
  await assertFails(getDocs(collection(as("mallory"), "inviteCodes")));
  await assertFails(getDoc(doc(as("mallory"), "inviteCodes/CODE2345")));
  await assertFails(getDoc(doc(as("bob"), "inviteCodes/CODE2345")));
  await assertFails(setDoc(doc(as("mallory"), "inviteCodes/FORGED22"), { uid: "alice", used: false, expiresAt: 9e15 }));
  await assertFails(updateDoc(doc(as("mallory"), "inviteCodes/CODE2345"), { used: true }));
});

test("approval budgets are server-only", async () => {
  await assertFails(getDoc(doc(as("bob"), "approvalBudgets/bob_2026-11-05")));
  await assertFails(setDoc(doc(as("bob"), "approvalBudgets/bob_2026-11-05"), { count: 0 }));
});

// ── usageStats and everything else ───────────────────────────────────────────

test("usage stats belong to their owner", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "usageStats/alice/daily/2026-11-05")));
  await assertSucceeds(setDoc(doc(as("alice"), "usageStats/alice/daily/2026-11-06"), { totalViceMinutes: 1 }));
  await assertFails(getDoc(doc(as("mallory"), "usageStats/alice/daily/2026-11-05")));
  await assertFails(setDoc(doc(as("mallory"), "usageStats/alice/daily/2026-11-06"), { totalViceMinutes: 0 }));
});

test("collections not named in the rules are denied", async () => {
  await assertFails(getDoc(doc(as("alice"), "somethingElse/x")));
  await assertFails(setDoc(doc(as("alice"), "somethingElse/x"), { a: 1 }));
});
