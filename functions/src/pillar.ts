import * as admin from "firebase-admin";

export const PILLAR_TITLES: Record<string, string[]> = {
  body:   ["The Dormant","The Stirring","The Moving","The Conditioned","The Athlete","The Forged","The Iron-Willed","The Unbreakable","The Titan","The Ascendant Body"],
  mind:   ["The Curious","The Student","The Learner","The Analyst","The Scholar","The Strategist","The Intellectual","The Polymath","The Sage","The Ascendant Mind"],
  spirit: ["The Restless","The Seeker","The Aware","The Present","The Centered","The Still","The Illumined","The Transcendent","The Boundless","The Ascendant Spirit"],
  career: ["The Idle","The Apprentice","The Craftsman","The Practitioner","The Builder","The Architect","The Innovator","The Visionary","The Pioneer","The Ascendant Legacy"],
  karma:  ["The Indifferent","The Kind","The Helper","The Generous","The Benefactor","The Mentor","The Altruist","The Luminary","The Beacon","The Ascendant Light"],
};

export const ALL_PILLARS = ["body", "mind", "spirit", "career", "karma"];

export function computeLevel(totalXp: number): number {
  if (totalXp <= 0) return 1;
  return Math.min(100, Math.floor((-1 + Math.sqrt(1 + 8 * totalXp / 100)) / 2) + 1);
}

export function xpForLevel(level: number): number {
  return 100 * level * (level - 1) / 2;
}

export function computeXpToNextLevel(currentXp: number, currentLevel: number): number {
  if (currentLevel >= 100) return 0;
  return xpForLevel(currentLevel + 1) - currentXp;
}

export function getLevelTitle(pillar: string, level: number): string {
  const titles = PILLAR_TITLES[pillar] ?? PILLAR_TITLES.body;
  const tierIndex = Math.min(9, Math.floor((level - 1) / 10));
  return titles[tierIndex];
}

export interface PillarUpdateResult {
  newXp: number;
  newLevel: number;
  newTitle: string;
  leveledUp: boolean;
}

export function computePillarUpdate(
  currentXp: number,
  currentLevel: number,
  pillar: string,
  xpToAdd: number
): PillarUpdateResult {
  const newXp = currentXp + xpToAdd;
  const newLevel = computeLevel(newXp);
  const newTitle = getLevelTitle(pillar, newLevel);
  return { newXp, newLevel, newTitle, leveledUp: newLevel > currentLevel };
}

export async function recomputeAscentScore(
  db: admin.firestore.Firestore,
  uid: string
): Promise<number> {
  let total = 0;
  for (const p of ALL_PILLARS) {
    const snap = await db.collection("users").doc(uid).collection("pillars").doc(p).get();
    total += snap.exists ? (snap.data()?.level ?? 1) : 1;
  }
  await db.collection("users").doc(uid).update({ totalAscentScore: total });
  return total;
}
