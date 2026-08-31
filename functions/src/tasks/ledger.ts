import { FieldValue, Firestore } from "firebase-admin/firestore";

interface InstanceSnapshot {
  status?: string;
  memberId?: string;
  pointsSnapshot?: number;
  reviewedByUid?: string;
  pointsAwarded?: number | null;
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
 * Reage à mudança de estado de uma `taskInstance`. Quando ela passa a
 * `approved`, credita os pontos no `ledger` — idempotente (id determinístico
 * `earn__{instanceId}`), então revisão dupla / duplo clique não credita duas
 * vezes.
 */
export async function onInstanceStatusChange(
  db: Firestore,
  familyId: string,
  instanceId: string,
  before: InstanceSnapshot | undefined,
  after: InstanceSnapshot | undefined,
): Promise<void> {
  if (!after) return; // deletada
  const wasApproved = before?.status === "approved";
  const isApproved = after.status === "approved";
  if (!isApproved || wasApproved) return;

  const points = after.pointsSnapshot ?? 0;
  const memberId = after.memberId;
  if (!memberId || points <= 0) return;

  const ledgerRef = db.doc(`families/${familyId}/ledger/earn__${instanceId}`);
  try {
    await ledgerRef.create({
      memberId,
      type: "earn",
      points,
      sourceType: "taskInstance",
      sourceId: instanceId,
      createdByUid: after.reviewedByUid ?? "system",
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (!isAlreadyExists(error)) throw error;
  }

  if (after.pointsAwarded !== points) {
    await db
      .doc(`families/${familyId}/taskInstances/${instanceId}`)
      .update({ pointsAwarded: points, updatedAt: FieldValue.serverTimestamp() });
  }
}
