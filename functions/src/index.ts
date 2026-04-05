import * as admin from "firebase-admin";
admin.initializeApp();

export { claimWellnessReward } from "./coins";
export { requestExtension, linkAccountabilityPartner, unlinkAccountabilityPartner } from "./partner";
