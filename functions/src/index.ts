import * as admin from "firebase-admin";
admin.initializeApp();

export { claimSessionXP } from "./sessions";
export { activateQuest, completeQuest } from "./quests";
export { checkAndAwardAchievements } from "./achievements";
