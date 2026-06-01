import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { ALL_PILLARS } from "./pillar";

interface AchievementDef {
  achievementId: string;
  title: string;
  description: string;
  category: string;
  pillar: string | null;
  badgeAsset: string;
}

const ACHIEVEMENTS: AchievementDef[] = [
  // First completions
  { achievementId: "first_body_quest",   title: "Body Awakened",   description: "Completed your first Body quest",   category: "first_completion", pillar: "body",   badgeAsset: "assets/badges/first_body.png" },
  { achievementId: "first_mind_quest",   title: "Mind Awakened",   description: "Completed your first Mind quest",   category: "first_completion", pillar: "mind",   badgeAsset: "assets/badges/first_mind.png" },
  { achievementId: "first_spirit_quest", title: "Spirit Awakened", description: "Completed your first Spirit quest", category: "first_completion", pillar: "spirit", badgeAsset: "assets/badges/first_spirit.png" },
  { achievementId: "first_career_quest", title: "Legacy Begins",   description: "Completed your first Career quest", category: "first_completion", pillar: "career", badgeAsset: "assets/badges/first_career.png" },
  { achievementId: "first_karma_quest",  title: "Karma Kindled",   description: "Completed your first Karma quest",  category: "first_completion", pillar: "karma",  badgeAsset: "assets/badges/first_karma.png" },
  { achievementId: "dawn_breaker",       title: "The Dawn Breaker", description: "Completed the first quest in every pillar", category: "title_unlock", pillar: null, badgeAsset: "assets/badges/dawn_breaker.png" },

  // Pillar milestones — body
  { achievementId: "body_level_5",  title: "Body: Level 5",  description: "Your Body pillar reached Level 5",  category: "pillar_milestone", pillar: "body", badgeAsset: "assets/badges/body_5.png" },
  { achievementId: "body_level_10", title: "Body: Level 10", description: "Your Body pillar reached Level 10", category: "pillar_milestone", pillar: "body", badgeAsset: "assets/badges/body_10.png" },
  { achievementId: "body_level_25", title: "Body: Level 25", description: "Your Body pillar reached Level 25", category: "pillar_milestone", pillar: "body", badgeAsset: "assets/badges/body_25.png" },
  { achievementId: "body_level_50", title: "Body: Level 50", description: "Your Body pillar reached Level 50", category: "pillar_milestone", pillar: "body", badgeAsset: "assets/badges/body_50.png" },

  // Pillar milestones — mind
  { achievementId: "mind_level_5",  title: "Mind: Level 5",  description: "Your Mind pillar reached Level 5",  category: "pillar_milestone", pillar: "mind", badgeAsset: "assets/badges/mind_5.png" },
  { achievementId: "mind_level_10", title: "Mind: Level 10", description: "Your Mind pillar reached Level 10", category: "pillar_milestone", pillar: "mind", badgeAsset: "assets/badges/mind_10.png" },
  { achievementId: "mind_level_25", title: "Mind: Level 25", description: "Your Mind pillar reached Level 25", category: "pillar_milestone", pillar: "mind", badgeAsset: "assets/badges/mind_25.png" },
  { achievementId: "mind_level_50", title: "Mind: Level 50", description: "Your Mind pillar reached Level 50", category: "pillar_milestone", pillar: "mind", badgeAsset: "assets/badges/mind_50.png" },

  // Pillar milestones — spirit
  { achievementId: "spirit_level_5",  title: "Spirit: Level 5",  description: "Your Spirit pillar reached Level 5",  category: "pillar_milestone", pillar: "spirit", badgeAsset: "assets/badges/spirit_5.png" },
  { achievementId: "spirit_level_10", title: "Spirit: Level 10", description: "Your Spirit pillar reached Level 10", category: "pillar_milestone", pillar: "spirit", badgeAsset: "assets/badges/spirit_10.png" },
  { achievementId: "spirit_level_25", title: "Spirit: Level 25", description: "Your Spirit pillar reached Level 25", category: "pillar_milestone", pillar: "spirit", badgeAsset: "assets/badges/spirit_25.png" },
  { achievementId: "spirit_level_50", title: "Spirit: Level 50", description: "Your Spirit pillar reached Level 50", category: "pillar_milestone", pillar: "spirit", badgeAsset: "assets/badges/spirit_50.png" },

  // Pillar milestones — career
  { achievementId: "career_level_5",  title: "Legacy: Level 5",  description: "Your Career pillar reached Level 5",  category: "pillar_milestone", pillar: "career", badgeAsset: "assets/badges/career_5.png" },
  { achievementId: "career_level_10", title: "Legacy: Level 10", description: "Your Career pillar reached Level 10", category: "pillar_milestone", pillar: "career", badgeAsset: "assets/badges/career_10.png" },
  { achievementId: "career_level_25", title: "Legacy: Level 25", description: "Your Career pillar reached Level 25", category: "pillar_milestone", pillar: "career", badgeAsset: "assets/badges/career_25.png" },
  { achievementId: "career_level_50", title: "Legacy: Level 50", description: "Your Career pillar reached Level 50", category: "pillar_milestone", pillar: "career", badgeAsset: "assets/badges/career_50.png" },

  // Pillar milestones — karma
  { achievementId: "karma_level_5",  title: "Karma: Level 5",  description: "Your Karma pillar reached Level 5",  category: "pillar_milestone", pillar: "karma", badgeAsset: "assets/badges/karma_5.png" },
  { achievementId: "karma_level_10", title: "Karma: Level 10", description: "Your Karma pillar reached Level 10", category: "pillar_milestone", pillar: "karma", badgeAsset: "assets/badges/karma_10.png" },
  { achievementId: "karma_level_25", title: "Karma: Level 25", description: "Your Karma pillar reached Level 25", category: "pillar_milestone", pillar: "karma", badgeAsset: "assets/badges/karma_25.png" },
  { achievementId: "karma_level_50", title: "Karma: Level 50", description: "Your Karma pillar reached Level 50", category: "pillar_milestone", pillar: "karma", badgeAsset: "assets/badges/karma_50.png" },

  // Streaks
  { achievementId: "streak_7",   title: "One Week Strong",    description: "Maintained a 7-day activity streak",   category: "streak", pillar: null, badgeAsset: "assets/badges/streak_7.png" },
  { achievementId: "streak_30",  title: "The Unbroken",       description: "Maintained a 30-day activity streak",  category: "title_unlock", pillar: null, badgeAsset: "assets/badges/streak_30.png" },
  { achievementId: "streak_100", title: "The Centurion",      description: "Maintained a 100-day activity streak", category: "streak", pillar: null, badgeAsset: "assets/badges/streak_100.png" },
  { achievementId: "streak_365", title: "The Eternal Flame",  description: "Maintained a 365-day activity streak", category: "title_unlock", pillar: null, badgeAsset: "assets/badges/streak_365.png" },

  // Composite title unlocks
  { achievementId: "title_ascendant",           title: "The Ascendant",           description: "Reached Level 10 in any pillar",                  category: "title_unlock", pillar: null, badgeAsset: "assets/badges/ascendant.png" },
  { achievementId: "title_polymath_initiate",   title: "The Polymath Initiate",   description: "Reached Level 5 in all five pillars",             category: "title_unlock", pillar: null, badgeAsset: "assets/badges/polymath_initiate.png" },
  { achievementId: "title_iron_sage",           title: "The Iron Sage",           description: "Body and Spirit both reached Level 30",           category: "title_unlock", pillar: null, badgeAsset: "assets/badges/iron_sage.png" },
  { achievementId: "title_benevolent_scholar",  title: "The Benevolent Scholar",  description: "Mind and Karma both reached Level 20",            category: "title_unlock", pillar: null, badgeAsset: "assets/badges/benevolent_scholar.png" },
  { achievementId: "title_silent_champion",     title: "The Silent Champion",     description: "Spirit and Body both reached Level 25",           category: "title_unlock", pillar: null, badgeAsset: "assets/badges/silent_champion.png" },
  { achievementId: "title_visionary_luminary",  title: "The Visionary Luminary",  description: "Career reached Level 30 and Karma reached Level 25", category: "title_unlock", pillar: null, badgeAsset: "assets/badges/visionary_luminary.png" },
  { achievementId: "title_complete_ascendant",  title: "The Complete Ascendant",  description: "All five pillars reached Level 50",               category: "title_unlock", pillar: null, badgeAsset: "assets/badges/complete_ascendant.png" },

  // Quest milestones
  { achievementId: "quest_10_mind",   title: "The Wandering Scholar", description: "Completed 10 Mind quests",  category: "title_unlock", pillar: "mind",  badgeAsset: "assets/badges/quest_10_mind.png" },
  { achievementId: "quest_10_body",   title: "Body of Work",          description: "Completed 10 Body quests",  category: "quest",        pillar: "body",  badgeAsset: "assets/badges/quest_10_body.png" },
  { achievementId: "quest_50_total",  title: "Fifty Ascents",         description: "Completed 50 quests total", category: "quest",        pillar: null,    badgeAsset: "assets/badges/quest_50.png" },
];

// Title unlocks: achievementId -> title to set as customTitle
const TITLE_UNLOCKS: Record<string, string> = {
  dawn_breaker:           "The Dawn Breaker",
  streak_30:              "The Unbroken",
  streak_365:             "The Eternal Flame",
  title_ascendant:        "The Ascendant",
  title_polymath_initiate:"The Polymath Initiate",
  title_iron_sage:        "The Iron Sage",
  title_benevolent_scholar:"The Benevolent Scholar",
  title_silent_champion:  "The Silent Champion",
  title_visionary_luminary:"The Visionary Luminary",
  title_complete_ascendant:"The Complete Ascendant",
  quest_10_mind:          "The Wandering Scholar",
};

export async function checkAchievements(
  db: admin.firestore.Firestore,
  uid: string
): Promise<string[]> {
  const userRef = db.collection("users").doc(uid);
  const [userSnap, ...pillarSnaps] = await Promise.all([
    userRef.get(),
    ...ALL_PILLARS.map(p => db.collection("users").doc(uid).collection("pillars").doc(p).get()),
  ]);

  if (!userSnap.exists) return [];

  const userData = userSnap.data()!;
  const pillarData: Record<string, { level: number; xp: number }> = {};
  ALL_PILLARS.forEach((p, i) => {
    const snap = pillarSnaps[i];
    pillarData[p] = { level: snap.exists ? (snap.data()?.level ?? 1) : 1, xp: snap.exists ? (snap.data()?.xp ?? 0) : 0 };
  });

  const questsSnap = await db.collection("users").doc(uid).collection("quests").where("status", "in", ["completed", "active"]).get();
  const completedQuests = questsSnap.docs.filter(d => d.data().status === "completed");
  const completedByPillar: Record<string, number> = {};
  let totalCompleted = 0;
  for (const doc of completedQuests) {
    const pillar = doc.data().pillar as string;
    completedByPillar[pillar] = (completedByPillar[pillar] ?? 0) + 1;
    totalCompleted++;
  }

  const existingAchievementsSnap = await db.collection("users").doc(uid).collection("achievements").get();
  const existing = new Set(existingAchievementsSnap.docs.map(d => d.id));

  const earned: string[] = [];

  function check(id: string, condition: boolean) {
    if (condition && !existing.has(id)) earned.push(id);
  }

  const streak = userData.currentStreak ?? 0;
  const allFirstCompleted = ALL_PILLARS.every(p => (completedByPillar[p] ?? 0) >= 1);

  // First completions
  check("first_body_quest",   (completedByPillar["body"]   ?? 0) >= 1);
  check("first_mind_quest",   (completedByPillar["mind"]   ?? 0) >= 1);
  check("first_spirit_quest", (completedByPillar["spirit"] ?? 0) >= 1);
  check("first_career_quest", (completedByPillar["career"] ?? 0) >= 1);
  check("first_karma_quest",  (completedByPillar["karma"]  ?? 0) >= 1);
  check("dawn_breaker", allFirstCompleted);

  // Pillar milestones
  for (const p of ALL_PILLARS) {
    const lvl = pillarData[p].level;
    check(`${p}_level_5`,  lvl >= 5);
    check(`${p}_level_10`, lvl >= 10);
    check(`${p}_level_25`, lvl >= 25);
    check(`${p}_level_50`, lvl >= 50);
  }

  // Streaks
  check("streak_7",   streak >= 7);
  check("streak_30",  streak >= 30);
  check("streak_100", streak >= 100);
  check("streak_365", streak >= 365);

  // Title unlocks
  check("title_ascendant",           ALL_PILLARS.some(p => pillarData[p].level >= 10));
  check("title_polymath_initiate",   ALL_PILLARS.every(p => pillarData[p].level >= 5));
  check("title_iron_sage",           pillarData["body"].level >= 30 && pillarData["spirit"].level >= 30);
  check("title_benevolent_scholar",  pillarData["mind"].level >= 20 && pillarData["karma"].level >= 20);
  check("title_silent_champion",     pillarData["spirit"].level >= 25 && pillarData["body"].level >= 25);
  check("title_visionary_luminary",  pillarData["career"].level >= 30 && pillarData["karma"].level >= 25);
  check("title_complete_ascendant",  ALL_PILLARS.every(p => pillarData[p].level >= 50));

  // Quest milestones
  check("quest_10_mind",  (completedByPillar["mind"] ?? 0) >= 10);
  check("quest_10_body",  (completedByPillar["body"] ?? 0) >= 10);
  check("quest_50_total", totalCompleted >= 50);

  if (earned.length === 0) return [];

  const defMap = new Map(ACHIEVEMENTS.map(a => [a.achievementId, a]));
  const batch = db.batch();
  let latestTitle: string | null = null;

  for (const id of earned) {
    const def = defMap.get(id);
    if (!def) continue;
    const ref = db.collection("users").doc(uid).collection("achievements").doc(id);
    batch.set(ref, {
      achievementId: id,
      title: def.title,
      description: def.description,
      category: def.category,
      earnedAt: admin.firestore.FieldValue.serverTimestamp(),
      pillar: def.pillar,
      badgeAsset: def.badgeAsset,
      isNew: true,
    });
    if (TITLE_UNLOCKS[id]) {
      latestTitle = TITLE_UNLOCKS[id];
    }
  }

  if (latestTitle) {
    batch.update(userRef, { customTitle: latestTitle });
  }

  await batch.commit();
  return earned;
}

export const checkAndAwardAchievements = functions.https.onCall(
  async (_data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Login required");
    }
    const db = admin.firestore();
    const earned = await checkAchievements(db, context.auth.uid);
    return { earned };
  }
);
