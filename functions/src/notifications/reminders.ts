import { Firestore } from "firebase-admin/firestore";

import { localDateStr } from "../shared/dates.js";
import { notifyUser, Sender } from "./messaging.js";

function localHourIn(timeZone: string, now: Date): number {
  return Number(
    new Intl.DateTimeFormat("en-GB", {
      timeZone,
      hour: "2-digit",
      hour12: false,
    }).format(now),
  );
}

/**
 * Para cada responsável: se a hora local da família dele bate com o
 * `reminderHour` configurado, o lembrete está ligado, ele ainda não recebeu
 * hoje, e há tarefas pendentes hoje na família — envia o lembrete (uma vez).
 */
export async function sendDueReminders(
  db: Firestore,
  opts: { now?: Date; sender?: Sender } = {},
): Promise<number> {
  const now = opts.now ?? new Date();
  const families = await db.collection("families").get();
  const handled = new Set<string>();
  let sent = 0;

  for (const family of families.docs) {
    const timezone = (family.data().timezone as string) ?? "America/Sao_Paulo";
    const dateStr = localDateStr(timezone, now);
    const localHour = localHourIn(timezone, now);
    let pendingCount: number | null = null;

    for (const uid of (family.data().guardianUids ?? []) as string[]) {
      if (handled.has(uid)) continue;

      const notif = (await db.collection("users").doc(uid).get()).data()?.notif ?? {};
      if (notif.dailyReminder === false) continue;
      if ((notif.reminderHour ?? 18) !== localHour) continue;
      if (notif.lastReminderDate === dateStr) continue;

      pendingCount ??= await countPendingToday(db, family.id, dateStr);
      if (pendingCount === 0) continue;

      handled.add(uid);
      sent += await notifyUser(
        db,
        uid,
        {
          title: "Tarefas de hoje",
          body:
            pendingCount === 1
              ? "1 tarefa ainda está pendente hoje."
              : `${pendingCount} tarefas ainda estão pendentes hoje.`,
          data: { type: "dailyReminder" },
        },
        opts.sender,
      );
      await db
        .collection("users")
        .doc(uid)
        .set({ notif: { lastReminderDate: dateStr } }, { merge: true });
    }
  }

  return sent;
}

async function countPendingToday(
  db: Firestore,
  familyId: string,
  dateStr: string,
): Promise<number> {
  const midnight = new Date(`${dateStr}T00:00:00.000Z`);
  const snap = await db
    .collection(`families/${familyId}/taskInstances`)
    .where("date", "==", midnight)
    .where("status", "==", "pending")
    .get();
  return snap.size;
}
