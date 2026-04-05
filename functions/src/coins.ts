import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const COIN_RATES: Record<string, number> = {
  wellnessBreathwork: 25,
  wellnessMeditation: 50,
  wellnessYoga: 75,
};

// Minimum elapsed time (seconds) per session type — 5% grace window applied
const REQUIRED_SECONDS: Record<string, number> = {
  breathwork: 285,  // 300 * 0.95
  meditation: 570,
  yoga:       855,
};

export const claimWellnessReward = functions.https.onCall(
  async (data: { sessionType: string; sessionToken: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { sessionType, sessionToken } = data;
    const uid = context.auth.uid;
    const db = admin.firestore();

    // --- Validate token ---
    const tokenRef = db.collection("wellnessTokens").doc(sessionToken);
    const tokenDoc = await tokenRef.get();

    if (!tokenDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Invalid session token");
    }

    const token = tokenDoc.data()!;

    if (token.uid !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Token does not belong to this user");
    }

    if (token.claimed === true) {
      throw new functions.https.HttpsError("already-exists", "Reward already claimed");
    }

    const issuedAt = token.issuedAt?.toMillis?.() ?? 0;
    const elapsedSeconds = (Date.now() - issuedAt) / 1000;
    const required = REQUIRED_SECONDS[sessionType] ?? 9999;

    if (elapsedSeconds < required) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Session too short: ${Math.round(elapsedSeconds)}s elapsed, ${required}s required`
      );
    }

    const coinKey = `wellness${sessionType.charAt(0).toUpperCase()}${sessionType.slice(1)}`;
    const reward = COIN_RATES[coinKey] ?? 0;

    // --- Atomic transaction: claim token + credit coins + reset mood ---
    await db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        throw new functions.https.HttpsError("not-found", "User document not found");
      }

      const currentCoins: number = userSnap.data()?.focusCoins ?? 0;

      tx.update(tokenRef, {
        claimed: true,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {
        focusCoins: currentCoins + reward,
        avatarMood: "ZEN",
        lastWellnessAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { coinsAwarded: reward };
  }
);
