import { Timestamp } from "firebase-admin/firestore";
import { Deps } from "./deps";

const ALREADY_EXISTS = 6; // gRPC status code

/**
 * Creates the profile every other function relies on. Clients can't create it
 * themselves, because that would let them choose their starting coin balance.
 */
export async function createUserProfile(
  { db, now }: Deps,
  uid: string,
  displayName: string | undefined
): Promise<void> {
  try {
    await db.collection("users").doc(uid).create({
      displayName: displayName ?? null,
      focusCoins: 0,
      avatarMood: "ZEN",
      createdAt: Timestamp.fromMillis(now()),
    });
  } catch (e) {
    // Auth triggers can fire more than once, and a repeat must not reset coins.
    if ((e as { code?: unknown }).code !== ALREADY_EXISTS) throw e;
  }
}
