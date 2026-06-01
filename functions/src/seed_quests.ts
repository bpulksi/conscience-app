import * as admin from "firebase-admin";

// Run once: ts-node seed_quests.ts
// Seeds the globalQuests collection with all 15 Open Ascent quests.

const quests = [
  // --- BODY ---
  {
    questId: "body_pushup_30day",
    name: "The 30-Day Push-Up Challenge",
    description: "Start with what you can. Add one rep each day. By day 30, your body is different. This quest tracks daily completions — missing a day resets your streak within the quest.",
    pillar: "body",
    difficulty: "journeyman",
    recurrence: "daily",
    xpReward: 60,
    durationSeconds: null,
    completionCriteria: "Log one push-up set per day for 30 consecutive days",
    pillarBonus: null,
    sortOrder: 10,
  },
  {
    questId: "body_yoga_21day",
    name: "The 21-Day Yoga Streak",
    description: "Yoga lives between body and spirit. Each session earns Spirit bonus XP, because the discipline of stillness trains both.",
    pillar: "body",
    difficulty: "journeyman",
    recurrence: "daily",
    xpReward: 80,
    durationSeconds: 900,
    completionCriteria: "Complete a timer-tracked yoga session for 21 consecutive days",
    pillarBonus: { pillar: "spirit", xp: 20 },
    sortOrder: 11,
  },
  {
    questId: "body_run_5k",
    name: "Run Your First 5K",
    description: "5 kilometers. No shortcuts. This is a one-time milestone quest — completing it permanently marks your foundation.",
    pillar: "body",
    difficulty: "expert",
    recurrence: "one_time",
    xpReward: 300,
    durationSeconds: null,
    completionCriteria: "Complete a continuous 5km run and mark as done",
    pillarBonus: null,
    sortOrder: 12,
  },

  // --- MIND ---
  {
    questId: "mind_pomodoro_4block",
    name: "The Pomodoro Protocol",
    description: "Four blocks. No phone. The Pomodoro method is the gateway drug to deep work. Timer runs continuously through all 4 blocks.",
    pillar: "mind",
    difficulty: "novice",
    recurrence: "daily",
    xpReward: 80,
    durationSeconds: 5760,
    completionCriteria: "Complete four 25-minute focused study/work blocks in one day",
    pillarBonus: null,
    sortOrder: 20,
  },
  {
    questId: "mind_course_chapter",
    name: "Chapter by Chapter",
    description: "Knowledge compounds. One chapter per week for a year is 52 chapters — roughly 3-4 complete books or courses.",
    pillar: "mind",
    difficulty: "novice",
    recurrence: "weekly",
    xpReward: 120,
    durationSeconds: null,
    completionCriteria: "Complete one chapter, module, or lesson from any course or book",
    pillarBonus: null,
    sortOrder: 21,
  },
  {
    questId: "mind_vocab_10words",
    name: "Vocabulary Builder",
    description: "Language is thought. Expanding your vocabulary expands how you can think. Use flashcards, Anki, or a notebook — whatever sticks.",
    pillar: "mind",
    difficulty: "novice",
    recurrence: "daily",
    xpReward: 40,
    durationSeconds: null,
    completionCriteria: "Learn and define 10 new words in any domain (language, technical, domain-specific)",
    pillarBonus: null,
    sortOrder: 22,
  },

  // --- SPIRIT ---
  {
    questId: "spirit_meditation_10min",
    name: "The Still Mind",
    description: "Sit. Watch your breath. Notice thoughts without following them. Scientific evidence is unambiguous: even 10 minutes daily restructures the brain in measurable ways.",
    pillar: "spirit",
    difficulty: "novice",
    recurrence: "daily",
    xpReward: 75,
    durationSeconds: 600,
    completionCriteria: "Complete a 10-minute timer-tracked meditation session",
    pillarBonus: { pillar: "body", xp: 15 },
    sortOrder: 30,
  },
  {
    questId: "spirit_breathwork_5min",
    name: "The Breath Reset",
    description: "Your nervous system has an off switch. It's your exhale. Five minutes of intentional breathing resets your cortisol baseline. Do this before any session you want to dominate.",
    pillar: "spirit",
    difficulty: "novice",
    recurrence: "daily",
    xpReward: 40,
    durationSeconds: 300,
    completionCriteria: "Complete a 5-minute guided breathwork session (box breathing, 4-7-8, or Wim Hof)",
    pillarBonus: { pillar: "body", xp: 10 },
    sortOrder: 31,
  },
  {
    questId: "spirit_gratitude_journal",
    name: "The Gratitude Page",
    description: "Gratitude rewires attention toward abundance. The Karma bonus exists because people who feel grateful give more freely.",
    pillar: "spirit",
    difficulty: "novice",
    recurrence: "daily",
    xpReward: 30,
    durationSeconds: 300,
    completionCriteria: "Write at least 3 specific gratitudes in a timed journaling session",
    pillarBonus: { pillar: "karma", xp: 15 },
    sortOrder: 32,
  },

  // --- CAREER ---
  {
    questId: "career_deep_work_90min",
    name: "The Deep Work Block",
    description: "Inspired by Cal Newport's \"Deep Work.\" No notifications. No music with lyrics. One task. The bonus Mind XP reflects that deep work trains concentration as powerfully as any study session.",
    pillar: "career",
    difficulty: "expert",
    recurrence: "daily",
    xpReward: 120,
    durationSeconds: 5400,
    completionCriteria: "Complete an uninterrupted 90-minute deep work session (phone off, timer running)",
    pillarBonus: { pillar: "mind", xp: 30 },
    sortOrder: 40,
  },
  {
    questId: "career_project_milestone",
    name: "The Milestone Marker",
    description: "You define what a milestone is. The key is that it must be something you can point to at the end of the week and say: this did not exist before.",
    pillar: "career",
    difficulty: "journeyman",
    recurrence: "weekly",
    xpReward: 200,
    durationSeconds: null,
    completionCriteria: "Complete a self-defined project milestone (shipped feature, finished proposal, landed client)",
    pillarBonus: null,
    sortOrder: 41,
  },
  {
    questId: "career_finance_article",
    name: "The Financial Lens",
    description: "Money is a system. Learning its rules is not optional for anyone building a legacy. One resource per week — in a year, you will have a financial education that most people never acquire.",
    pillar: "career",
    difficulty: "novice",
    recurrence: "weekly",
    xpReward: 60,
    durationSeconds: null,
    completionCriteria: "Read one article, chapter, or video on personal finance, investing, or economics",
    pillarBonus: { pillar: "mind", xp: 20 },
    sortOrder: 42,
  },

  // --- KARMA ---
  {
    questId: "karma_random_kindness",
    name: "The Kind Gesture",
    description: "Open a door. Pay for someone's coffee. Send a genuine compliment. Write about what you did in the completion note. The act matters. So does the reflection.",
    pillar: "karma",
    difficulty: "novice",
    recurrence: "daily",
    xpReward: 50,
    durationSeconds: null,
    completionCriteria: "Perform and log one intentional act of kindness toward a stranger, friend, or family member",
    pillarBonus: null,
    sortOrder: 50,
  },
  {
    questId: "karma_mentor_someone",
    name: "Pass It Forward",
    description: "Teaching forces you to understand. The Mind XP bonus recognizes that the best way to master a subject is to be responsible for someone else's understanding of it.",
    pillar: "karma",
    difficulty: "journeyman",
    recurrence: "weekly",
    xpReward: 150,
    durationSeconds: null,
    completionCriteria: "Spend at least 30 minutes helping or mentoring someone with a skill, problem, or goal",
    pillarBonus: { pillar: "mind", xp: 25 },
    sortOrder: 51,
  },
  {
    questId: "karma_volunteer_2hr",
    name: "Volunteer Hours",
    description: "Two hours is nothing to lose and everything to give. The Spirit bonus reflects the research finding that volunteering is one of the highest predictors of subjective wellbeing.",
    pillar: "karma",
    difficulty: "expert",
    recurrence: "weekly",
    xpReward: 250,
    durationSeconds: null,
    completionCriteria: "Volunteer at least 2 hours for a cause, organization, or community effort",
    pillarBonus: { pillar: "spirit", xp: 40 },
    sortOrder: 52,
  },
];

async function seed() {
  admin.initializeApp();
  const db = admin.firestore();
  const batch = db.batch();
  for (const q of quests) {
    const { questId, ...rest } = q;
    batch.set(db.collection("globalQuests").doc(questId), rest);
  }
  await batch.commit();
  console.log(`Seeded ${quests.length} quests to globalQuests collection.`);
}

seed().catch(console.error);
