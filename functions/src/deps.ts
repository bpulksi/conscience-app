import type { Firestore } from "firebase-admin/firestore";

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

/**
 * Everything the business logic needs from the outside world. Passing it in
 * keeps the logic testable without a Firebase project or emulator.
 */
export interface Deps {
  db: Firestore;
  now: () => number;
  sendPush: (message: PushMessage) => Promise<void>;
}

/** Firestore auto-IDs are 20 alphanumerics; rejects "/" so input can't address another path. */
export const DOC_ID_PATTERN = /^[A-Za-z0-9]{1,64}$/;
