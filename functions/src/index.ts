import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { setGlobalOptions } from "firebase-functions/v2";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
// Auth "user created" triggers are only available in the v1 API.
import * as functionsV1 from "firebase-functions/v1";
import * as coins from "./coins";
import { Deps } from "./deps";
import * as partner from "./partner";
import { createUserProfile } from "./users";

initializeApp();
setGlobalOptions({ maxInstances: 10 });

const deps: Deps = {
  db: getFirestore(),
  now: () => Date.now(),
  sendPush: async ({ token, title, body, data }) => {
    await getMessaging().send({
      token,
      notification: { title, body },
      data,
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  },
};

function requireUid(request: CallableRequest): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  return request.auth.uid;
}

export const startWellnessSession = onCall((req) =>
  coins.startWellnessSession(deps, requireUid(req), req.data)
);
export const claimWellnessReward = onCall((req) =>
  coins.claimWellnessReward(deps, requireUid(req), req.data)
);

export const createInviteCode = onCall((req) =>
  partner.createInviteCode(deps, requireUid(req))
);
export const linkAccountabilityPartner = onCall((req) =>
  partner.linkAccountabilityPartner(deps, requireUid(req), req.data)
);
export const unlinkAccountabilityPartner = onCall((req) =>
  partner.unlinkAccountabilityPartner(deps, requireUid(req))
);
export const requestExtension = onCall((req) =>
  partner.requestExtension(deps, requireUid(req))
);
export const respondToExtension = onCall((req) =>
  partner.respondToExtension(deps, requireUid(req), req.data)
);

export const onUserCreated = functionsV1.auth
  .user()
  .onCreate((user) => createUserProfile(deps, user.uid, user.displayName));
