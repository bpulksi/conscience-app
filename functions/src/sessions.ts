import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { computeLevel, computeXpToNextLevel, getLevelTitle, computePillarUpdate, ALL_PILLARS, recomputeAscentScore } from "./pillar";
import { checkAchievements } from "./achievements";

const XP_RATES: Record<string, number> = {
  meditation: 75,
  breathwork: 40,
  yoga:       60,
  deep_work:  120,
  study:      80,
  exercise:   60,
  journaling: 30,
};

const REQUIRED_SECONDS: Record<string, number> = {
  meditation: 570,
  breathwork: 285,
  yoga:       855,
  deep_work:  5130,
  study:      2565,
  exercise:   1710,
  journaling: 285,
};

const PILLAR_BONUS: Record<string, { pillar: string; xp: number }> = {
  yoga:       { pillar: "spirit", xp: 20 },
  meditation: { pillar: "body",   xp: 15 },
  breathwork: { pillar: "body",   xp: 10 },
  journaling: { pillar: "karma",  xp: 15 },
  deep_work:  { pillar: "mind",   xp: 30 },
};

export const claimSessionXP = functions.https.onCall(
  async (data: { activityType: string; pillar: string; sessionToken: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { activityType, pillar, sessionToken } = data;
    const uid = context.auth.uid;
    const db = admin.firestore();

    const tokenRef = db.collection("sessionTokens").doc(sessionToken);
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
    const required = REQUIRED_SECONDS[activityType] ?? 285;

    if (elapsedSeconds < required) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Session too short: ${Math.round(elapsedSeconds)}s elapsed, ${required}s required`
      );
    }

    const xpReward = XP_RATES[activityType] ?? 30;
    const bonus = PILLAR_BONUS[activityType] ?? null;

    const userRef = db.collection("users").doc(uid);
    const pillarRef = db.collection("users").doc(uid).collection("pillars").doc(pillar);
    const bonusPillarRef = bonus
      ? db.collection("users").doc(uid).collection("pillars").doc(bonus.pillar)
      : null;
    const sessionRef = db.collection("users").doc(uid).collection("sessions").doc();

    let newLevel = 1;
    let newTitle = "";
    let bonusXp = 0;
    let bonusPillarId = "";

    await db.runTransaction(async (tx) => {
      // --- All reads first ---
      const [tokenSnap, userSnap, pillarSnap] = await Promise.all([
        tx.get(tokenRef),
        tx.get(userRef),
        tx.get(pillarRef),
      ]);
      const bonusPillarSnap = bonusPillarRef ? await tx.get(bonusPillarRef) : null;

      if (tokenSnap.data()?.claimed === true) {
        throw new functions.https.HttpsError("already-exists", "Reward already claimed");
      }
      if (!userSnap.exists) {
        throw new functions.https.HttpsError("not-found", "User not found");
      }

      // --- Compute pillar update ---
      const currentXp = pillarSnap.exists ? (pillarSnap.data()?.xp ?? 0) : 0;
      const currentLevel = pillarSnap.exists ? (pillarSnap.data()?.level ?? 1) : 1;
      const pillarUpdate = computePillarUpdate(currentXp, currentLevel, pillar, xpReward);
      newLevel = pillarUpdate.newLevel;
      newTitle = pillarUpdate.newTitle;

      // --- Compute bonus pillar update ---
      let bonusPillarUpdate = null;
      if (bonus && bonusPillarSnap) {
        const bXp = bonusPillarSnap.exists ? (bonusPillarSnap.data()?.xp ?? 0) : 0;
        const bLevel = bonusPillarSnap.exists ? (bonusPillarSnap.data()?.level ?? 1) : 1;
        bonusPillarUpdate = computePillarUpdate(bXp, bLevel, bonus.pillar, bonus.xp);
        bonusXp = bonus.xp;
        bonusPillarId = bonus.pillar;
      }

      // --- Compute streak ---
      const userData = userSnap.data()!;
      const now = new Date();
      const today = now.toISOString().split("T")[0];
      const yesterday = new Date(now);
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().split("T")[0];

      const lastActivityDate: string = userData.lastActivityDate ?? "";
      const currentStreak: number = userData.currentStreak ?? 0;
      const longestStreak: number = userData.longestStreak ?? 0;

      let newStreak = currentStreak;
      if (lastActivityDate === today) {
        newStreak = currentStreak;
      } else if (lastActivityDate === yesterdayStr) {
        newStreak = currentStreak + 1;
      } else {
        newStreak = 1;
      }

      // --- All writes ---
      tx.update(tokenRef, {
        claimed: true,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(pillarRef, {
        pillarId: pillar,
        xp: pillarUpdate.newXp,
        level: pillarUpdate.newLevel,
        levelTitle: pillarUpdate.newTitle,
        xpToNextLevel: computeXpToNextLevel(pillarUpdate.newXp, pillarUpdate.newLevel),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (bonusPillarUpdate && bonusPillarRef) {
        tx.set(bonusPillarRef, {
          pillarId: bonus!.pillar,
          xp: bonusPillarUpdate.newXp,
          level: bonusPillarUpdate.newLevel,
          levelTitle: bonusPillarUpdate.newTitle,
          xpToNextLevel: computeXpToNextLevel(bonusPillarUpdate.newXp, bonusPillarUpdate.newLevel),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      tx.set(sessionRef, {
        pillar,
        activityType,
        durationSeconds: Math.round(elapsedSeconds),
        xpAwarded: xpReward,
        bonusXpPillar: bonus?.pillar ?? null,
        bonusXp: bonus?.xp ?? 0,
        sessionToken,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {
        lastActivityDate: today,
        currentStreak: newStreak,
        longestStreak: Math.max(longestStreak, newStreak),
      });
    });

    // Recompute aggregate score outside transaction
    await recomputeAscentScore(db, uid);

    // Check achievements fire-and-forget
    checkAchievements(db, uid).catch(() => {});

    return { xpAwarded: xpReward, bonusXp, bonusPillar: bonusPillarId, newLevel, newTitle };
  }
);
