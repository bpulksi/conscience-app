import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const MAX_DAILY_APPROVALS = 2;
const REQUEST_TTL_MS = 5 * 60 * 1000; // 5 minutes

// ── Link / Unlink ────────────────────────────────────────────────────────────

export const linkAccountabilityPartner = functions.https.onCall(
  async (data: { inviteCode: string }, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Login required");

    const uid = context.auth.uid;
    const db = admin.firestore();
    const code = data.inviteCode?.toUpperCase();

    if (!code) throw new functions.https.HttpsError("invalid-argument", "Invite code required");

    const codeRef = db.collection("inviteCodes").doc(code);
    const codeDoc = await codeRef.get();

    if (!codeDoc.exists) throw new functions.https.HttpsError("not-found", "Invite code not found");
    if (codeDoc.data()?.used) throw new functions.https.HttpsError("already-exists", "Invite code already used");

    const partnerId: string = codeDoc.data()!.uid;

    if (partnerId === uid) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot partner with yourself");
    }

    // Check for same-device abuse
    const [userSnap, partnerSnap] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("users").doc(partnerId).get(),
    ]);

    if (
      userSnap.data()?.deviceFingerprint &&
      userSnap.data()?.deviceFingerprint === partnerSnap.data()?.deviceFingerprint
    ) {
      throw new functions.https.HttpsError("permission-denied", "Cannot partner with yourself");
    }

    // Atomic: mark code used + link both users
    await db.runTransaction(async (tx) => {
      tx.update(codeRef, { used: true, usedBy: uid, usedAt: admin.firestore.FieldValue.serverTimestamp() });
      tx.update(db.collection("users").doc(uid), { accountabilityPartner: partnerId });
      tx.update(db.collection("users").doc(partnerId), { accountabilityPartner: uid });
    });

    return { partnerId };
  }
);

export const unlinkAccountabilityPartner = functions.https.onCall(
  async (_data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Login required");

    const uid = context.auth.uid;
    const db = admin.firestore();
    const userSnap = await db.collection("users").doc(uid).get();
    const partnerId: string | undefined = userSnap.data()?.accountabilityPartner;

    const batch = db.batch();
    batch.update(db.collection("users").doc(uid), { accountabilityPartner: admin.firestore.FieldValue.delete() });
    if (partnerId) {
      batch.update(db.collection("users").doc(partnerId), { accountabilityPartner: admin.firestore.FieldValue.delete() });
    }
    await batch.commit();

    return { success: true };
  }
);

// ── Extension Requests ────────────────────────────────────────────────────────

export const requestExtension = functions.https.onCall(
  async (_data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Login required");

    const uid = context.auth.uid;
    const db = admin.firestore();
    const messaging = admin.messaging();

    const userSnap = await db.collection("users").doc(uid).get();
    const partnerId: string | undefined = userSnap.data()?.accountabilityPartner;

    if (!partnerId) {
      throw new functions.https.HttpsError("not-found", "No accountability partner linked");
    }

    // Check daily approval budget
    const today = new Date().toISOString().split("T")[0];
    const budgetRef = db.collection("approvalBudgets").doc(`${partnerId}_${today}`);
    const budgetSnap = await budgetRef.get();
    const used: number = budgetSnap.data()?.count ?? 0;

    if (used >= MAX_DAILY_APPROVALS) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Your partner has used their daily approval budget"
      );
    }

    // Check for pending request that hasn't expired
    const existing = await db.collection("extensionRequests")
      .where("requesterId", "==", uid)
      .where("status", "==", "pending")
      .where("expiresAt", ">", Date.now())
      .limit(1)
      .get();

    if (!existing.empty) {
      throw new functions.https.HttpsError("already-exists", "A pending request already exists");
    }

    const partnerSnap = await db.collection("users").doc(partnerId).get();
    const requesterName: string = userSnap.data()?.displayName ?? "Your partner";

    // Create request
    const requestRef = await db.collection("extensionRequests").add({
      requesterId: uid,
      requesterName,
      partnerId,
      status: "pending",
      createdAt: Date.now(),
      expiresAt: Date.now() + REQUEST_TTL_MS,
    });

    // Push notification to partner
    const fcmToken: string | undefined = partnerSnap.data()?.fcmToken;
    if (fcmToken) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: `${requesterName} needs 10 more minutes`,
            body: "They've hit their limit. Approve or deny?",
          },
          data: {
            type: "extensionRequest",
            requestId: requestRef.id,
          },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
      } catch (e) {
        // Don't fail the request if FCM errors — partner will see it in-app
        console.warn("FCM send failed:", e);
      }
    }

    return { requestId: requestRef.id };
  }
);

// Triggered when partner updates a request to "approved"
export const onExtensionApproved = functions.firestore
  .document("extensionRequests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === "pending" && after.status === "approved") {
      const db = admin.firestore();
      const messaging = admin.messaging();
      const today = new Date().toISOString().split("T")[0];

      // Increment partner's daily approval count
      const budgetRef = db.collection("approvalBudgets").doc(`${after.partnerId}_${today}`);
      await budgetRef.set({ count: admin.firestore.FieldValue.increment(1) }, { merge: true });

      // Notify requester
      const requesterSnap = await db.collection("users").doc(after.requesterId).get();
      const fcmToken: string | undefined = requesterSnap.data()?.fcmToken;

      if (fcmToken) {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: "Extension approved!",
            body: "You have 10 more minutes. Make them count.",
          },
          data: { type: "extensionApproved" },
        });
      }
    }
  });
