import assert from "node:assert/strict";
import { Deps, PushMessage } from "../deps";
import { FakeFirestore } from "./fakeFirestore";

export const START = Date.UTC(2026, 10, 5, 12, 0, 0);
export const MINUTE = 60 * 1000;

export function setup(uids: string[] = ["alice", "bob"]) {
  const fake = new FakeFirestore();
  uids.forEach((uid) => fake.seed(`users/${uid}`, { displayName: uid, focusCoins: 0 }));

  const clock = { ms: START };
  const pushes: PushMessage[] = [];
  const deps: Deps = {
    db: fake.asFirestore(),
    now: () => clock.ms,
    sendPush: async (message) => {
      pushes.push(message);
    },
  };

  return { fake, deps, pushes, advance: (ms: number) => void (clock.ms += ms) };
}

/** Asserts that a call was rejected with the given callable error code. */
export async function rejectsWith(call: Promise<unknown>, code: string) {
  await assert.rejects(call, (e: { code?: string }) => {
    assert.equal(e.code, code);
    return true;
  });
}
