import { Firestore } from "firebase-admin/firestore";

import { localDateStr } from "../shared/dates.js";
import { notifyUser, Sender } from "./messaging.js";

/**
 * Para cada família, no fuso dela: se a hora local bate com o `reminderHour`
 * de algum responsável (que não desligou o lembrete e ainda não recebeu hoje)
 * e há tarefas pendentes hoje, envia o lembrete.
 */
export async function sendDueReminders(
  db: Firestore,
  opts: { now?: Date; sender?: Sender } = {},
): Promise<number> {
  const now = opts.now ?? new Date();
  const families = await db.collection("families").get();
  let sent = 0;

  for (const family of families.docs) {
    const timezone = (family.data().timezone as string) ?? "America/Sao_Paulo";
    const dateStr = localDateStr(timezone, now);
    const localHour = Number(
      new Intl.DateTimeFormat("en-GB", {
        timeZone: timezone,
        hour: "2-digit",
        hour12: false,
      }).format(now),
    );

    const uids = (family.data().guardianUids ?? []) as string[];
    let pendingCount: number | null = null;

    for (const uid of uids) {
      const user = await db.collection("users").doc(uid).get();
      const notif = user.data()?.notif ?? {};
      if (notif.dailyReminder === false) continue;
      if ((notif.reminderHour ?? 18) !== localHour) continue;
      if (notif.lastReminderDate === dateStr) continue;

      if (pendingCount === null) {
        pendingCount = await countPendingToday(db, family.id, dateStr);
      }
      if (pendingCount > 0) {
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
      }
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
