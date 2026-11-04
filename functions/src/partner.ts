import { randomInt } from "crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError } from "firebase-functions/v2/https";
import { Deps, DOC_ID_PATTERN, PushMessage } from "./deps";

export const MAX_DAILY_APPROVALS = 2;
export const REQUEST_TTL_MS = 5 * 60 * 1000;
export const INVITE_TTL_MS = 24 * 60 * 60 * 1000;

const INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I
const INVITE_LENGTH = 8;

function newInviteCode(): string {
  let code = "";
  for (let i = 0; i < INVITE_LENGTH; i++) {
    code += INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)];
  }
  return code;
}

/** Budgets roll over at midnight UTC. */
function budgetId(partnerId: string, nowMs: number): string {
  return `${partnerId}_${new Date(nowMs).toISOString().split("T")[0]}`;
}

/** A failed push must never undo a request or approval already saved. */
async function sendBestEffort(deps: Deps, message: PushMessage): Promise<void> {
  try {
    await deps.sendPush(message);
  } catch (e) {
    logger.warn("FCM send failed", e);
  }
}

// ── Link / Unlink ────────────────────────────────────────────────────────────

/** Issues a random, expiring code and revokes any unused earlier one. */
export async function createInviteCode(
  { db, now }: Deps,
  uid: string
): Promise<{ code: string; expiresAt: number }> {
  const code = newInviteCode();
  const expiresAt = now() + INVITE_TTL_MS;
  const codes = db.collection("inviteCodes");
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User document not found");
    }
    if (userSnap.data()?.accountabilityPartner) {
      throw new HttpsError("failed-precondition", "You already have a partner");
    }

    const earlier = await tx.get(
      codes.where("uid", "==", uid).where("used", "==", false)
    );
    earlier.docs.forEach((doc) => tx.delete(doc.ref));

    tx.create(codes.doc(code), {
      uid,
      used: false,
      createdAt: Timestamp.fromMillis(now()),
      expiresAt,
    });
  });

  return { code, expiresAt };
}

export async function linkAccountabilityPartner(
  { db, now }: Deps,
  uid: string,
  data: { inviteCode?: unknown }
): Promise<{ partnerId: string }> {
  const raw = data?.inviteCode;
  const code = typeof raw === "string" ? raw.trim().toUpperCase() : "";
  if (!DOC_ID_PATTERN.test(code)) {
    throw new HttpsError("invalid-argument", "Invite code required");
  }

  const codeRef = db.collection("inviteCodes").doc(code);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const codeSnap = await tx.get(codeRef);
    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "Invite code not found");
    }

    const invite = codeSnap.data()!;
    if (invite.used) {
      throw new HttpsError("already-exists", "Invite code already used");
    }
    if (invite.expiresAt <= now()) {
      throw new HttpsError("deadline-exceeded", "Invite code expired");
    }

    const partnerId: string = invite.uid;
    if (partnerId === uid) {
      throw new HttpsError("invalid-argument", "Cannot partner with yourself");
    }

    const partnerRef = db.collection("users").doc(partnerId);
    const [userSnap, partnerSnap] = [await tx.get(userRef), await tx.get(partnerRef)];

    if (!userSnap.exists || !partnerSnap.exists) {
      throw new HttpsError("not-found", "User document not found");
    }
    if (userSnap.data()?.accountabilityPartner || partnerSnap.data()?.accountabilityPartner) {
      throw new HttpsError("failed-precondition", "One of you already has a partner");
    }

    tx.update(codeRef, { used: true, usedBy: uid, usedAt: Timestamp.fromMillis(now()) });
    tx.update(userRef, { accountabilityPartner: partnerId });
    tx.update(partnerRef, { accountabilityPartner: uid });

    return { partnerId };
  });
}

export async function unlinkAccountabilityPartner(
  { db }: Deps,
  uid: string
): Promise<{ success: true }> {
  const users = db.collection("users");
  const userRef = users.doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const partnerId: string | undefined = userSnap.data()?.accountabilityPartner;
    if (!partnerId) return;

    const partnerRef = users.doc(partnerId);
    const partnerSnap = await tx.get(partnerRef);

    tx.update(userRef, { accountabilityPartner: FieldValue.delete() });
    // Only clear the other side if it still points back at this user.
    if (partnerSnap.data()?.accountabilityPartner === uid) {
      tx.update(partnerRef, { accountabilityPartner: FieldValue.delete() });
    }
  });

  return { success: true };
}

// ── Extension Requests ────────────────────────────────────────────────────────

export async function requestExtension(
  deps: Deps,
  uid: string
): Promise<{ requestId: string }> {
  const { db, now } = deps;
  const requests = db.collection("extensionRequests");
  const requestRef = requests.doc();
  const userRef = db.collection("users").doc(uid);

  const { requesterName, partnerFcmToken } = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const partnerId: string | undefined = userSnap.data()?.accountabilityPartner;
    if (!partnerId) {
      throw new HttpsError("not-found", "No accountability partner linked");
    }

    const budgetRef = db.collection("approvalBudgets").doc(budgetId(partnerId, now()));
    const budgetSnap = await tx.get(budgetRef);
    if ((budgetSnap.data()?.count ?? 0) >= MAX_DAILY_APPROVALS) {
      throw new HttpsError("resource-exhausted", "Your partner has used their daily approval budget");
    }

    const pending = await tx.get(
      requests
        .where("requesterId", "==", uid)
        .where("status", "==", "pending")
        .where("expiresAt", ">", now())
        .limit(1)
    );
    if (!pending.empty) {
      throw new HttpsError("already-exists", "A pending request already exists");
    }

    const partnerSnap = await tx.get(db.collection("users").doc(partnerId));
    const name: string = userSnap.data()?.displayName ?? "Your partner";

    tx.create(requestRef, {
      requesterId: uid,
      requesterName: name,
      partnerId,
      status: "pending",
      createdAt: now(),
      expiresAt: now() + REQUEST_TTL_MS,
    });

    return {
      requesterName: name,
      partnerFcmToken: partnerSnap.data()?.fcmToken as string | undefined,
    };
  });

  if (partnerFcmToken) {
    await sendBestEffort(deps, {
      token: partnerFcmToken,
      title: `${requesterName} needs 10 more minutes`,
      body: "They've hit their limit. Approve or deny?",
      data: { type: "extensionRequest", requestId: requestRef.id },
    });
  }

  return { requestId: requestRef.id };
}

/**
 * The only way to answer a request. The daily budget is counted in the same
 * transaction as the approval, so simultaneous approvals can't exceed it.
 */
export async function respondToExtension(
  deps: Deps,
  uid: string,
  data: { requestId?: unknown; approved?: unknown }
): Promise<{ status: "approved" | "denied" }> {
  const { db, now } = deps;
  const { requestId, approved } = data ?? {};

  if (typeof requestId !== "string" || !DOC_ID_PATTERN.test(requestId)) {
    throw new HttpsError("invalid-argument", "Invalid request id");
  }
  if (typeof approved !== "boolean") {
    throw new HttpsError("invalid-argument", "approved must be true or false");
  }

  const requestRef = db.collection("extensionRequests").doc(requestId);
  const budgetRef = db.collection("approvalBudgets").doc(budgetId(uid, now()));
  const userRef = db.collection("users").doc(uid);

  const outcome = await db.runTransaction(async (tx) => {
    const requestSnap = await tx.get(requestRef);
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Request not found");
    }

    const request = requestSnap.data()!;
    if (request.partnerId !== uid) {
      throw new HttpsError("permission-denied", "This request isn't addressed to you");
    }
    if (request.status !== "pending") {
      throw new HttpsError("failed-precondition", "Request already answered");
    }

    // Saved rather than thrown: throwing would roll back the status change.
    if (request.expiresAt <= now()) {
      tx.update(requestRef, { status: "expired" });
      return { expired: true as const };
    }

    const userSnap = await tx.get(userRef);
    if (userSnap.data()?.accountabilityPartner !== request.requesterId) {
      throw new HttpsError("failed-precondition", "You are no longer linked to this person");
    }

    const requesterSnap = await tx.get(db.collection("users").doc(request.requesterId));

    if (approved) {
      const budgetSnap = await tx.get(budgetRef);
      const used: number = budgetSnap.data()?.count ?? 0;
      if (used >= MAX_DAILY_APPROVALS) {
        throw new HttpsError("resource-exhausted", "You have used today's approvals");
      }
      tx.set(budgetRef, { count: used + 1 }, { merge: true });
    }

    tx.update(requestRef, {
      status: approved ? "approved" : "denied",
      respondedAt: Timestamp.fromMillis(now()),
    });

    return {
      expired: false as const,
      requesterFcmToken: requesterSnap.data()?.fcmToken as string | undefined,
    };
  });

  if (outcome.expired) {
    throw new HttpsError("deadline-exceeded", "Request expired");
  }

  if (approved && outcome.requesterFcmToken) {
    await sendBestEffort(deps, {
      token: outcome.requesterFcmToken,
      title: "Extension approved!",
      body: "You have 10 more minutes. Make them count.",
      data: { type: "extensionApproved" },
    });
  }

  return { status: approved ? "approved" : "denied" };
}
