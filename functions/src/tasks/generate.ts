import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";

import { localDateStr, utcMidnight } from "../shared/dates.js";
import { occursOn, Recurrence } from "./recurrence.js";

export interface GenerateResult {
  familyId: string;
  dateStr: string;
  created: number;
}

/** ID determinístico da ocorrência — garante idempotência. */
export function instanceId(taskId: string, memberId: string, dateStr: string): string {
  return `${taskId}__${memberId}__${dateStr}`;
}

function toRecurrence(raw: Record<string, unknown> | undefined): Recurrence {
  const startTs = raw?.startDate as Timestamp | undefined;
  const endTs = raw?.endDate as Timestamp | null | undefined;
  return {
    type: (raw?.type as Recurrence["type"]) ?? "once",
    daysOfWeek: (raw?.daysOfWeek as number[] | undefined) ?? [],
    startDate: startTs?.toDate ? startTs.toDate() : new Date(0),
    endDate: endTs?.toDate ? endTs.toDate() : null,
  };
}

function isAlreadyExists(error: unknown): boolean {
  const e = error as { code?: number | string; message?: string };
  return (
    e.code === 6 ||
    e.code === "already-exists" ||
    /ALREADY_EXISTS/.test(e.message ?? "")
  );
}

/**
 * Cria as ocorrências ("taskInstances") do dia local da família para todas as
 * tarefas ativas cuja recorrência bate com a data. Idempotente: rodar de novo
 * não duplica.
 */
export async function generateForFamily(
  db: Firestore,
  familyId: string,
  opts: { now?: Date } = {},
): Promise<GenerateResult> {
  const now = opts.now ?? new Date();
  const familySnap = await db.collection("families").doc(familyId).get();
  if (!familySnap.exists) return { familyId, dateStr: "", created: 0 };

  const timezone = (familySnap.data()?.timezone as string) ?? "America/Sao_Paulo";
  const dateStr = localDateStr(timezone, now);
  const instanceDate = Timestamp.fromDate(utcMidnight(dateStr));

  const [tasksSnap, childrenSnap] = await Promise.all([
    db.collection(`families/${familyId}/tasks`).where("active", "==", true).get(),
    db
      .collection(`families/${familyId}/members`)
      .where("type", "==", "child")
      .get(),
  ]);

  const childIds = new Set(childrenSnap.docs.map((d) => d.id));
  const childUidById = new Map(
    childrenSnap.docs.map((d) => [
      d.id,
      d.data().linkedUid as string | undefined,
    ]),
  );
  let created = 0;

  for (const taskDoc of tasksSnap.docs) {
    const task = taskDoc.data();
    if (!occursOn(toRecurrence(task.recurrence), dateStr)) continue;

    const assignee = task.assigneeMemberId as string | null | undefined;
    const targets = assignee ? [assignee] : [...childIds];

    for (const memberId of targets) {
      if (!childIds.has(memberId)) continue; // criança removida

      const ref = db.doc(
        `families/${familyId}/taskInstances/${instanceId(taskDoc.id, memberId, dateStr)}`,
      );
      const memberUid = childUidById.get(memberId);
      try {
        await ref.create({
          taskId: taskDoc.id,
          memberId,
          ...(memberUid ? { memberUid } : {}),
          date: instanceDate,
          status: "pending",
          titleSnapshot: task.title ?? "",
          pointsSnapshot: task.points ?? 0,
          requiresApproval: task.requiresApproval ?? true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        created += 1;
      } catch (error) {
        if (!isAlreadyExists(error)) throw error;
      }
    }
  }

  return { familyId, dateStr, created };
}

/** Gera para todas as famílias (usado pela função agendada). */
export async function generateAllFamilies(
  db: Firestore,
  opts: { now?: Date } = {},
): Promise<GenerateResult[]> {
  const families = await db.collection("families").get();
  const results: GenerateResult[] = [];
  for (const family of families.docs) {
    results.push(await generateForFamily(db, family.id, opts));
  }
  return results;
}
