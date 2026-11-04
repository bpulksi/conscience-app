import assert from "node:assert/strict";
import { test } from "node:test";
import { CLAIM_WINDOW_MS, claimWellnessReward, startWellnessSession } from "../coins";
import { createUserProfile } from "../users";
import { MINUTE, rejectsWith, setup } from "./harness";

test("pays the session's reward once enough time has passed", async () => {
  const { deps, fake, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "meditation" });
  advance(9.5 * MINUTE);

  assert.deepEqual(await claimWellnessReward(deps, "alice", { sessionToken }), { coinsAwarded: 50 });
  assert.equal(fake.read("users/alice")?.focusCoins, 50);
  assert.equal(fake.read("users/alice")?.activeWellnessToken, undefined);
});

test("rejects a claim made too early", async () => {
  const { deps, fake, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "meditation" });
  advance(9 * MINUTE);

  await rejectsWith(claimWellnessReward(deps, "alice", { sessionToken }), "failed-precondition");
  assert.equal(fake.read("users/alice")?.focusCoins, 0);
});

test("the start time is set by the server and client input can't change it", async () => {
  const { deps, fake } = setup();
  const data = { sessionType: "yoga", issuedAt: 0 };
  const { sessionToken } = await startWellnessSession(deps, "alice", data);

  assert.equal(fake.read(`wellnessTokens/${sessionToken}`)?.issuedAt.toMillis(), deps.now());
  await rejectsWith(claimWellnessReward(deps, "alice", { sessionToken }), "failed-precondition");
});

test("simultaneous claims of one token pay out once", async () => {
  const { deps, fake, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "yoga" });
  advance(15 * MINUTE);

  const results = await Promise.allSettled(
    Array.from({ length: 5 }, () => claimWellnessReward(deps, "alice", { sessionToken }))
  );

  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(fake.read("users/alice")?.focusCoins, 75);
});

test("a claimed token can't be claimed again", async () => {
  const { deps, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "breathwork" });
  advance(5 * MINUTE);
  await claimWellnessReward(deps, "alice", { sessionToken });

  await rejectsWith(claimWellnessReward(deps, "alice", { sessionToken }), "already-exists");
});

test("stacked sessions can't all be claimed", async () => {
  const { deps, fake, advance } = setup();
  const first = await startWellnessSession(deps, "alice", { sessionType: "yoga" });
  const second = await startWellnessSession(deps, "alice", { sessionType: "yoga" });
  advance(15 * MINUTE);

  await rejectsWith(claimWellnessReward(deps, "alice", first), "failed-precondition");
  await claimWellnessReward(deps, "alice", second);
  assert.equal(fake.read("users/alice")?.focusCoins, 75);
});

test("a session left too long expires", async () => {
  const { deps, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "breathwork" });
  advance(5 * MINUTE + CLAIM_WINDOW_MS + 1);

  await rejectsWith(claimWellnessReward(deps, "alice", { sessionToken }), "deadline-exceeded");
});

test("the reward comes from the stored session type, not the client", async () => {
  const { deps, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "breathwork" });
  advance(5 * MINUTE);

  const result = await claimWellnessReward(deps, "alice", { sessionToken, sessionType: "yoga" } as object);
  assert.equal(result.coinsAwarded, 25);
});

test("another user's token is rejected", async () => {
  const { deps, advance } = setup();
  const { sessionToken } = await startWellnessSession(deps, "alice", { sessionType: "breathwork" });
  advance(5 * MINUTE);

  await rejectsWith(claimWellnessReward(deps, "bob", { sessionToken }), "permission-denied");
});

test("bad input is rejected", async () => {
  const { deps } = setup();
  for (const sessionType of ["sleep", "__proto__", 5, undefined]) {
    await rejectsWith(startWellnessSession(deps, "alice", { sessionType }), "invalid-argument");
  }
  for (const sessionToken of ["", "users/alice", 5, undefined]) {
    await rejectsWith(claimWellnessReward(deps, "alice", { sessionToken }), "invalid-argument");
  }
});

test("a repeated sign-up trigger doesn't reset an existing profile", async () => {
  const { deps, fake } = setup([]);
  await createUserProfile(deps, "carol", "Carol");
  assert.equal(fake.read("users/carol")?.focusCoins, 0);

  fake.seed("users/carol", { ...fake.read("users/carol"), focusCoins: 40 });
  await createUserProfile(deps, "carol", "Carol");
  assert.equal(fake.read("users/carol")?.focusCoins, 40);
});
