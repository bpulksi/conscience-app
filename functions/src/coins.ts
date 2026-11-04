import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { Deps, DOC_ID_PATTERN } from "./deps";

const SESSIONS = new Map<string, { durationSeconds: number; coins: number }>([
  ["breathwork", { durationSeconds: 300, coins: 25 }],
  ["meditation", { durationSeconds: 600, coins: 50 }],
  ["yoga", { durationSeconds: 900, coins: 75 }],
]);

/** A session may be claimed once 95% of its duration has passed. */
const MIN_ELAPSED_RATIO = 0.95;
/** How long after a session's nominal end it can still be claimed. */
export const CLAIM_WINDOW_MS = 30 * 60 * 1000;

/**
 * Starts a session. The server sets the start time, and each user has one
 * active session, so sessions can't be backdated or stacked to claim together.
 */
export async function startWellnessSession(
  { db, now }: Deps,
  uid: string,
  data: { sessionType?: unknown }
): Promise<{ sessionToken: string }> {
  const sessionType = data?.sessionType;
  if (typeof sessionType !== "string" || !SESSIONS.has(sessionType)) {
    throw new HttpsError("invalid-argument", "Unknown session type");
  }

  const userRef = db.collection("users").doc(uid);
  const tokenRef = db.collection("wellnessTokens").doc();

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User document not found");
    }
    tx.set(tokenRef, {
      uid,
      sessionType,
      issuedAt: Timestamp.fromMillis(now()),
      claimed: false,
    });
    tx.update(userRef, { activeWellnessToken: tokenRef.id });
  });

  return { sessionToken: tokenRef.id };
}

/**
 * Pays out a finished session. All checks run inside the transaction, so
 * simultaneous claims of one token can't both succeed. The session type comes
 * from the stored token and never from the client.
 */
export async function claimWellnessReward(
  { db, now }: Deps,
  uid: string,
  data: { sessionToken?: unknown }
): Promise<{ coinsAwarded: number }> {
  const sessionToken = data?.sessionToken;
  if (typeof sessionToken !== "string" || !DOC_ID_PATTERN.test(sessionToken)) {
    throw new HttpsError("invalid-argument", "Invalid session token");
  }

  const tokenRef = db.collection("wellnessTokens").doc(sessionToken);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [tokenSnap, userSnap] = [await tx.get(tokenRef), await tx.get(userRef)];

    if (!tokenSnap.exists) {
      throw new HttpsError("not-found", "Invalid session token");
    }
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User document not found");
    }

    const token = tokenSnap.data()!;
    const user = userSnap.data()!;

    if (token.uid !== uid) {
      throw new HttpsError("permission-denied", "Token does not belong to this user");
    }
    if (token.claimed === true) {
      throw new HttpsError("already-exists", "Reward already claimed");
    }
    if (user.activeWellnessToken !== sessionToken) {
      throw new HttpsError("failed-precondition", "A newer session has replaced this one");
    }

    const session = SESSIONS.get(token.sessionType);
    if (!session) {
      throw new HttpsError("failed-precondition", "Unknown session type");
    }

    const elapsedMs = now() - (token.issuedAt as Timestamp).toMillis();
    const durationMs = session.durationSeconds * 1000;

    if (elapsedMs < durationMs * MIN_ELAPSED_RATIO) {
      throw new HttpsError("failed-precondition", "Session too short");
    }
    if (elapsedMs > durationMs + CLAIM_WINDOW_MS) {
      throw new HttpsError("deadline-exceeded", "Session expired");
    }

    const claimedAt = Timestamp.fromMillis(now());
    tx.update(tokenRef, { claimed: true, claimedAt });
    tx.update(userRef, {
      focusCoins: (user.focusCoins ?? 0) + session.coins,
      avatarMood: "ZEN",
      lastWellnessAt: claimedAt,
      activeWellnessToken: FieldValue.delete(),
    });

    return { coinsAwarded: session.coins };
  });
}
