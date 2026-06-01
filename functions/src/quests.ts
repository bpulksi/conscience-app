import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { computeLevel, computeXpToNextLevel, getLevelTitle, computePillarUpdate, recomputeAscentScore } from "./pillar";
import { checkAchievements } from "./achievements";

export const activateQuest = functions.https.onCall(
  async (data: { questId: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { questId } = data;
    const uid = context.auth.uid;
    const db = admin.firestore();

    const globalQuestSnap = await db.collection("globalQuests").doc(questId).get();
    if (!globalQuestSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Quest not found");
    }

    const questDef = globalQuestSnap.data()!;
    const userQuestRef = db.collection("users").doc(uid).collection("quests").doc(questId);
    const userQuestSnap = await userQuestRef.get();

    if (userQuestSnap.exists) {
      const status = userQuestSnap.data()?.status;
      if (status === "active") {
        throw new functions.https.HttpsError("already-exists", "Quest already active");
      }
      if (status === "completed" && questDef.recurrence === "one_time") {
        throw new functions.https.HttpsError("already-exists", "One-time quest already completed");
      }
    }

    await userQuestRef.set({
      questId,
      pillar: questDef.pillar,
      status: "active",
      progressCount: 0,
      completedAt: null,
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastCompletedAt: null,
      recurrence: questDef.recurrence,
      xpAwarded: 0,
    });

    return { success: true };
  }
);

export const completeQuest = functions.https.onCall(
  async (data: { questId: string; completionNote?: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }

    const { questId } = data;
    const uid = context.auth.uid;
    const db = admin.firestore();

    const userQuestRef = db.collection("users").doc(uid).collection("quests").doc(questId);
    const globalQuestRef = db.collection("globalQuests").doc(questId);

    const [userQuestSnap, globalQuestSnap] = await Promise.all([
      userQuestRef.get(),
      globalQuestRef.get(),
    ]);

    if (!userQuestSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Quest not activated — activate it first");
    }
    if (!globalQuestSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Quest definition not found");
    }

    const userQuest = userQuestSnap.data()!;
    const questDef = globalQuestSnap.data()!;

    if (userQuest.status !== "active") {
      throw new functions.https.HttpsError("failed-precondition", "Quest is not active");
    }

    // Recurrence guard
    const now = new Date();
    const todayStr = now.toISOString().split("T")[0];
    const lastCompletedAt = userQuest.lastCompletedAt?.toDate?.() ?? null;

    if (questDef.recurrence === "daily" && lastCompletedAt) {
      const lastStr = lastCompletedAt.toISOString().split("T")[0];
      if (lastStr === todayStr) {
        throw new functions.https.HttpsError("failed-precondition", "Daily quest already completed today");
      }
    }

    if (questDef.recurrence === "weekly" && lastCompletedAt) {
      const getWeek = (d: Date) => {
        const jan1 = new Date(d.getFullYear(), 0, 1);
        return Math.ceil((((d.getTime() - jan1.getTime()) / 86400000) + jan1.getDay() + 1) / 7);
      };
      if (getWeek(lastCompletedAt) === getWeek(now) && lastCompletedAt.getFullYear() === now.getFullYear()) {
        throw new functions.https.HttpsError("failed-precondition", "Weekly quest already completed this week");
      }
    }

    const xpReward: number = questDef.xpReward ?? 50;
    const pillar: string = questDef.pillar;
    const bonusDef = questDef.pillarBonus ?? null;

    const pillarRef = db.collection("users").doc(uid).collection("pillars").doc(pillar);
    const bonusPillarRef = bonusDef
      ? db.collection("users").doc(uid).collection("pillars").doc(bonusDef.pillar)
      : null;
    const userRef = db.collection("users").doc(uid);

    let newLevel = 1;
    let newTitle = "";

    await db.runTransaction(async (tx) => {
      // Reads first
      const [pillarSnap, userSnap] = await Promise.all([
        tx.get(pillarRef),
        tx.get(userRef),
      ]);
      const bonusPillarSnap = bonusPillarRef ? await tx.get(bonusPillarRef) : null;

      if (!userSnap.exists) {
        throw new functions.https.HttpsError("not-found", "User not found");
      }

      // Pillar XP
      const currentXp = pillarSnap.exists ? (pillarSnap.data()?.xp ?? 0) : 0;
      const currentLevel = pillarSnap.exists ? (pillarSnap.data()?.level ?? 1) : 1;
      const pillarUpdate = computePillarUpdate(currentXp, currentLevel, pillar, xpReward);
      newLevel = pillarUpdate.newLevel;
      newTitle = pillarUpdate.newTitle;

      // Bonus pillar
      let bonusPillarUpdate = null;
      if (bonusDef && bonusPillarSnap) {
        const bXp = bonusPillarSnap.exists ? (bonusPillarSnap.data()?.xp ?? 0) : 0;
        const bLevel = bonusPillarSnap.exists ? (bonusPillarSnap.data()?.level ?? 1) : 1;
        bonusPillarUpdate = computePillarUpdate(bXp, bLevel, bonusDef.pillar, bonusDef.xp);
      }

      // Streak
      const userData = userSnap.data()!;
      const today = todayStr;
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

      // Writes
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
          pillarId: bonusDef!.pillar,
          xp: bonusPillarUpdate.newXp,
          level: bonusPillarUpdate.newLevel,
          levelTitle: bonusPillarUpdate.newTitle,
          xpToNextLevel: computeXpToNextLevel(bonusPillarUpdate.newXp, bonusPillarUpdate.newLevel),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const isOneTime = questDef.recurrence === "one_time";
      const newProgress = (userQuest.progressCount ?? 0) + 1;

      tx.update(userQuestRef, {
        status: isOneTime ? "completed" : "active",
        progressCount: newProgress,
        lastCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: isOneTime ? admin.firestore.FieldValue.serverTimestamp() : null,
        xpAwarded: admin.firestore.FieldValue.increment(xpReward),
      });

      tx.update(userRef, {
        lastActivityDate: today,
        currentStreak: newStreak,
        longestStreak: Math.max(longestStreak, newStreak),
      });
    });

    await recomputeAscentScore(db, uid);
    checkAchievements(db, uid).catch(() => {});

    return { xpAwarded: xpReward, newLevel, newTitle };
  }
);
