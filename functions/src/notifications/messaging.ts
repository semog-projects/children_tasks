import { Firestore } from "firebase-admin/firestore";
import { getMessaging, Messaging } from "firebase-admin/messaging";

export interface Notif {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export type PrefKey =
  | "pendingApproval"
  | "approvalResult"
  | "redemption"
  | "dailyReminder"
  | "taskApproved"
  | "taskRejected"
  | "rewardDelivered";

interface Target {
  uid: string;
  token: string;
}

function isStaleToken(error: unknown): boolean {
  const code = (error as { code?: string })?.code ?? "";
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    code === "messaging/invalid-argument"
  );
}

/** Injetável para testes; por padrão usa o Messaging real. */
export interface Sender {
  send(tokens: string[], notif: Notif): Promise<{ successes: boolean[] }>;
}

class RealSender implements Sender {
  constructor(private readonly messaging: Messaging) {}
  async send(tokens: string[], notif: Notif) {
    const res = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title: notif.title, body: notif.body },
      data: notif.data ?? {},
    });
    return {
      successes: res.responses.map((r) => {
        if (r.success) return true;
        return !isStaleToken(r.error);
      }),
    };
  }
}

async function tokensForUser(db: Firestore, uid: string): Promise<Target[]> {
  const snap = await db.collection(`users/${uid}/fcmTokens`).get();
  return snap.docs.map((d) => ({ uid, token: d.id }));
}

async function sendAndClean(
  db: Firestore,
  targets: Target[],
  notif: Notif,
  sender: Sender,
): Promise<number> {
  if (targets.length === 0) return 0;
  const { successes } = await sender.send(
    targets.map((t) => t.token),
    notif,
  );
  const stale: Target[] = [];
  successes.forEach((ok, i) => {
    if (!ok) stale.push(targets[i]);
  });
  await Promise.all(
    stale.map((t) => db.doc(`users/${t.uid}/fcmTokens/${t.token}`).delete()),
  );
  return targets.length - stale.length;
}

/**
 * Notifica os responsáveis da família cujo pref [prefKey] não está desligado.
 * Retorna quantos envios foram bem-sucedidos.
 */
export async function notifyGuardians(
  db: Firestore,
  familyId: string,
  prefKey: PrefKey,
  notif: Notif,
  sender: Sender = new RealSender(getMessaging()),
): Promise<number> {
  const fam = await db.collection("families").doc(familyId).get();
  const uids = (fam.data()?.guardianUids ?? []) as string[];

  const targets: Target[] = [];
  for (const uid of uids) {
    const user = await db.collection("users").doc(uid).get();
    if (user.data()?.notif?.[prefKey] === false) continue;
    targets.push(...(await tokensForUser(db, uid)));
  }
  return sendAndClean(db, targets, notif, sender);
}

/** Notifica um usuário específico (usado pelo lembrete diário). */
export async function notifyUser(
  db: Firestore,
  uid: string,
  notif: Notif,
  sender: Sender = new RealSender(getMessaging()),
): Promise<number> {
  return sendAndClean(db, await tokensForUser(db, uid), notif, sender);
}

/**
 * Notifica a criança dona de [memberId], se ela tem login próprio
 * (`members/{id}.linkedUid`) e o pref [prefKey] não está desligado (#35).
 */
export async function notifyMember(
  db: Firestore,
  familyId: string,
  memberId: string,
  prefKey: PrefKey,
  notif: Notif,
  sender: Sender = new RealSender(getMessaging()),
): Promise<number> {
  const member = await db.doc(`families/${familyId}/members/${memberId}`).get();
  const uid = member.data()?.linkedUid as string | undefined;
  if (!uid) return 0;
  const user = await db.collection("users").doc(uid).get();
  if (user.data()?.notif?.[prefKey] === false) return 0;
  return notifyUser(db, uid, notif, sender);
}
