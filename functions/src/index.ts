/**
 * Cloud Functions do children_tasks.
 *
 * - generateDailyInstances: agendada, materializa as tarefas do dia (#10)
 * - generateInstances: callable, para o app forçar a geração ao abrir (#10)
 * - onTaskInstanceWritten: credita pontos + notifica responsável e criança
 *   (aprovação / rejeição) (#11/#14/#35)
 * - redeemReward: callable, resgate transacional (responsável ou criança) (#12/#35)
 * - onRedemptionWritten: notifica responsável (resgatado) / criança (entregue)
 * - requestCashOut/approveCashOut: callable, câmbio de pontos por dinheiro (#66)
 * - onCashOutWritten: notifica responsável (pedido) / criança (aprovado/pago/recusado)
 * - sendDailyReminders: agendada, lembrete diário de tarefas pendentes (#14)
 * - createFamilyInvite/acceptFamilyInvite: callable, convite e vínculo de
 *   criança / responsável à família (#33)
 * - listFamilyInvites/revokeFamilyInvite: callable, convites em aberto (#36)
 */

import { initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { onSchedule } from "firebase-functions/v2/scheduler";

import {
  acceptInvite,
  createInvite,
  InviteError,
  listOpenInvites,
  revokeInvite,
} from "./family/invites.js";
import {
  approveCashOut as approveCashOutTx,
  CashOutError,
  requestCashOut as requestCashOutTx,
} from "./cashout/cashout.js";
import { notifyGuardians, notifyMember } from "./notifications/messaging.js";
import { sendDueReminders } from "./notifications/reminders.js";
import {
  redeemReward as redeemRewardTx,
  RedeemError,
  resolveRedeemTarget,
} from "./rewards/redeem.js";
import { generateAllFamilies, generateForFamily } from "./tasks/generate.js";
import { onInstanceStatusChange } from "./tasks/ledger.js";

async function childName(
  db: Firestore,
  familyId: string,
  memberId: string,
): Promise<string> {
  const snap = await db.doc(`families/${familyId}/members/${memberId}`).get();
  return (snap.data()?.displayName as string | undefined) ?? "A criança";
}

async function assertGuardian(
  db: Firestore,
  familyId: string,
  uid: string,
): Promise<void> {
  const snap = await db.collection("families").doc(familyId).get();
  const uids = (snap.data()?.guardianUids ?? []) as string[];
  if (!snap.exists || !uids.includes(uid)) {
    throw new HttpsError("permission-denied", "Você não é responsável desta família.");
  }
}

initializeApp();

const REGION = "southamerica-east1";

/**
 * Roda de hora em hora. Para cada família, gera as ocorrências do dia local
 * dela. Idempotente — rodar de novo não duplica.
 */
export const generateDailyInstances = onSchedule(
  { schedule: "every 60 minutes", region: REGION, timeZone: "America/Sao_Paulo" },
  async () => {
    const results = await generateAllFamilies(getFirestore());
    const total = results.reduce((sum, r) => sum + r.created, 0);
    logger.info("generateDailyInstances", { families: results.length, created: total });
  },
);

/**
 * Callable: gera as ocorrências do dia para uma família do responsável logado.
 * Sem `familyId`, gera para todas as famílias em que ele é responsável.
 */
export const generateInstances = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Faça login.");

    const db = getFirestore();
    const familyId = request.data?.familyId as string | undefined;

    let families;
    if (familyId) {
      await assertGuardian(db, familyId, uid);
      families = [familyId];
    } else {
      const snap = await db
        .collection("families")
        .where("guardianUids", "array-contains", uid)
        .get();
      families = snap.docs.map((d) => d.id);
    }

    const results = [];
    for (const id of families) {
      results.push(await generateForFamily(db, id));
    }
    return { results };
  },
);

/**
 * Reage à mudança de estado de uma ocorrência:
 *  - credita os pontos no `ledger` ao aprovar (idempotente);
 *  - notifica os responsáveis (pendência de aprovação / resultado).
 */
export const onTaskInstanceWritten = onDocumentWritten(
  {
    document: "families/{familyId}/taskInstances/{instanceId}",
    region: REGION,
  },
  async (event) => {
    const { familyId, instanceId } = event.params;
    const db = getFirestore();
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    await onInstanceStatusChange(db, familyId, instanceId, before, after);

    if (!after) return;
    const title = (after.titleSnapshot as string) ?? "A tarefa";

    // criança marcou feita -> aguardando aprovação
    if (before?.status !== "awaitingApproval" && after.status === "awaitingApproval") {
      const name = await childName(db, familyId, after.memberId as string);
      await notifyGuardians(db, familyId, "pendingApproval", {
        title: "Tarefa para aprovar",
        body: `${name} marcou "${title}" como feita.`,
        data: { type: "pendingApproval", instanceId },
      });
      return;
    }

    // aprovada
    if (before?.status !== "approved" && after.status === "approved") {
      const memberId = after.memberId as string;
      const name = await childName(db, familyId, memberId);
      const points = after.pointsSnapshot ?? 0;
      await notifyGuardians(db, familyId, "approvalResult", {
        title: "Tarefa aprovada 🎉",
        body: `"${title}" de ${name} — +${points} pontos.`,
        data: { type: "approvalResult", instanceId },
      });
      await notifyMember(db, familyId, memberId, "taskApproved", {
        title: "Tarefa aprovada 🎉",
        body: `"${title}" — +${points} pontos!`,
        data: { type: "taskApproved", instanceId },
      });
      return;
    }

    // rejeitada (volta para pending com um motivo novo)
    if (
      after.status === "pending" &&
      after.rejectionReason &&
      before?.rejectionReason !== after.rejectionReason
    ) {
      const memberId = after.memberId as string;
      const name = await childName(db, familyId, memberId);
      await notifyGuardians(db, familyId, "approvalResult", {
        title: "Tarefa para refazer",
        body: `"${title}" de ${name}: ${after.rejectionReason}`,
        data: { type: "approvalResult", instanceId },
      });
      await notifyMember(db, familyId, memberId, "taskRejected", {
        title: "Tarefa para refazer",
        body: `"${title}": ${after.rejectionReason}`,
        data: { type: "taskRejected", instanceId },
      });
    }
  },
);

/** Notifica o responsável quando uma criança resgata uma recompensa. */
/**
 * Resgate criado -> notifica os responsáveis ("hora de entregar").
 * Resgate marcado como `delivered` -> notifica a criança ("recompensa
 * entregue"). (#14/#35)
 */
export const onRedemptionWritten = onDocumentWritten(
  {
    document: "families/{familyId}/redemptions/{redemptionId}",
    region: REGION,
  },
  async (event) => {
    const { familyId, redemptionId } = event.params;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;
    const db = getFirestore();
    const memberId = after.memberId as string;
    const rewardTitle = (after.rewardTitleSnapshot as string) ?? "uma recompensa";

    if (!before) {
      const name = await childName(db, familyId, memberId);
      await notifyGuardians(db, familyId, "redemption", {
        title: "Recompensa resgatada",
        body: `${name} resgatou "${rewardTitle}" (${after.cost ?? 0} pts). Hora de entregar!`,
        data: { type: "redemption", redemptionId },
      });
      return;
    }

    if (before.status !== "delivered" && after.status === "delivered") {
      await notifyMember(db, familyId, memberId, "rewardDelivered", {
        title: "Recompensa entregue 🎉",
        body: `"${rewardTitle}" já é sua!`,
        data: { type: "rewardDelivered", redemptionId },
      });
    }
  },
);

function formatBrlCents(cents: number): string {
  const reais = Math.trunc(cents / 100);
  const rest = Math.abs(cents % 100)
    .toString()
    .padStart(2, "0");
  return `R$ ${reais},${rest}`;
}

/**
 * Câmbio de pontos por dinheiro (#66):
 * - pedido criado (`requested`) -> notifica os responsáveis;
 * - `requested -> approved` -> notifica a criança ("aprovado");
 * - `approved -> paid` -> notifica a criança ("pago");
 * - `requested -> rejected` -> notifica a criança ("recusado" + motivo).
 */
export const onCashOutWritten = onDocumentWritten(
  {
    document: "families/{familyId}/cashOuts/{cashOutId}",
    region: REGION,
  },
  async (event) => {
    const { familyId, cashOutId } = event.params;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;
    const db = getFirestore();
    const memberId = after.memberId as string;
    const amount = formatBrlCents((after.amountCents as number | undefined) ?? 0);
    const points = (after.points as number | undefined) ?? 0;

    if (!before) {
      const name = await childName(db, familyId, memberId);
      await notifyGuardians(db, familyId, "cashOut", {
        title: "Pedido de troca por dinheiro",
        body: `${name} quer trocar ${points} pontos por ${amount}.`,
        data: { type: "cashOut", cashOutId },
      });
      return;
    }

    if (before.status === after.status) return;

    if (after.status === "approved") {
      await notifyMember(db, familyId, memberId, "cashOut", {
        title: "Troca aprovada 💸",
        body: `${amount} a caminho (−${points} pontos).`,
        data: { type: "cashOut", cashOutId },
      });
    } else if (after.status === "paid") {
      await notifyMember(db, familyId, memberId, "cashOut", {
        title: "Dinheiro pago 🎉",
        body: `${amount} já é seu!`,
        data: { type: "cashOut", cashOutId },
      });
    } else if (after.status === "rejected") {
      const note = (after.note as string | undefined)?.trim();
      await notifyMember(db, familyId, memberId, "cashOut", {
        title: "Troca recusada",
        body: note
          ? `Seu pedido de ${amount} foi recusado: ${note}`
          : `Seu pedido de ${amount} foi recusado.`,
        data: { type: "cashOut", cashOutId },
      });
    }
  },
);

/**
 * De hora em hora: para cada responsável, se a hora local da família bate com
 * o horário do lembrete configurado e há tarefas pendentes hoje, envia o
 * lembrete (uma vez por dia).
 */
export const sendDailyReminders = onSchedule(
  { schedule: "every 60 minutes", region: REGION, timeZone: "America/Sao_Paulo" },
  async () => {
    const sent = await sendDueReminders(getFirestore());
    logger.info("sendDailyReminders", { sent });
  },
);

/**
 * Callable (responsável): gera um convite para vincular uma criança
 * (`role: "child"`, `memberId`) ou adicionar um responsável (`role:
 * "guardian"`, `email` opcional). Retorna o código e a data de expiração.
 */
export const createFamilyInvite = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");

  const familyId = request.data?.familyId as string | undefined;
  const role = request.data?.role as string | undefined;
  if (!familyId || (role !== "child" && role !== "guardian")) {
    throw new HttpsError("invalid-argument", "familyId e role são obrigatórios.");
  }

  const db = getFirestore();
  try {
    const { code, expiresAt } = await createInvite(db, {
      familyId,
      createdByUid: uid,
      role,
      memberId: request.data?.memberId as string | undefined,
      email: request.data?.email as string | undefined,
    });
    return { code, expiresAt: expiresAt.toISOString() };
  } catch (error) {
    if (error instanceof InviteError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});

/** Callable (responsável): convites em aberto da família. */
export const listFamilyInvites = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");
  const familyId = request.data?.familyId as string | undefined;
  if (!familyId) throw new HttpsError("invalid-argument", "familyId é obrigatório.");

  const db = getFirestore();
  try {
    const invites = await listOpenInvites(db, familyId, uid);
    return {
      invites: invites.map((i) => ({
        ...i,
        expiresAt: i.expiresAt.toISOString(),
      })),
    };
  } catch (error) {
    if (error instanceof InviteError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});

/** Callable (responsável): revoga um convite ainda não aceito. */
export const revokeFamilyInvite = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");
  const code = request.data?.code as string | undefined;
  if (!code) throw new HttpsError("invalid-argument", "code é obrigatório.");

  const db = getFirestore();
  try {
    await revokeInvite(db, code, uid);
    return { ok: true };
  } catch (error) {
    if (error instanceof InviteError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});

/**
 * Callable (autenticado): aceita um convite pelo código. Vincula a conta à
 * criança / adiciona como responsável. Idempotente.
 */
export const acceptFamilyInvite = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");

  const code = request.data?.code as string | undefined;
  if (!code) throw new HttpsError("invalid-argument", "code é obrigatório.");

  const db = getFirestore();
  try {
    return await acceptInvite(db, {
      code,
      uid,
      displayName: (request.auth?.token.name as string | undefined) ?? null,
      email: (request.auth?.token.email as string | undefined) ?? null,
      photoUrl: (request.auth?.token.picture as string | undefined) ?? null,
    });
  } catch (error) {
    if (error instanceof InviteError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});

/**
 * Resgate de recompensa: débito transacional de pontos (sem saldo negativo)
 * + registro de resgate. Pode ser chamado pelo responsável (para qualquer
 * criança) ou pela própria criança logada (só para si — issue #35).
 */
export const redeemReward = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");

  const familyId = request.data?.familyId as string | undefined;
  const rewardId = request.data?.rewardId as string | undefined;
  if (!familyId || !rewardId) {
    throw new HttpsError("invalid-argument", "familyId e rewardId são obrigatórios.");
  }

  const db = getFirestore();
  try {
    const target = await resolveRedeemTarget(
      db,
      familyId,
      uid,
      request.data?.memberId as string | undefined,
    );
    return await redeemRewardTx(db, {
      familyId,
      rewardId,
      memberId: target.memberId,
      memberUid: target.memberUid,
      requestedByUid: uid,
    });
  } catch (error) {
    if (error instanceof RedeemError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});

/**
 * Câmbio (#66): a criança (ou o responsável) pede a troca de N pontos por
 * dinheiro. Só cria o pedido `requested` — o débito é na aprovação.
 */
export const requestCashOut = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");

  const familyId = request.data?.familyId as string | undefined;
  const points = request.data?.points as number | undefined;
  if (!familyId || typeof points !== "number") {
    throw new HttpsError("invalid-argument", "familyId e points são obrigatórios.");
  }

  const db = getFirestore();
  try {
    const target = await resolveRedeemTarget(
      db,
      familyId,
      uid,
      request.data?.memberId as string | undefined,
    );
    return await requestCashOutTx(db, {
      familyId,
      memberId: target.memberId,
      memberUid: target.memberUid,
      points,
      requestedByUid: uid,
    });
  } catch (error) {
    if (error instanceof CashOutError || error instanceof RedeemError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});

/**
 * Câmbio (#66): o responsável aprova um pedido `requested` — débito
 * transacional de pontos (sem saldo negativo) e status `approved`.
 */
export const approveCashOut = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Faça login.");

  const familyId = request.data?.familyId as string | undefined;
  const cashOutId = request.data?.cashOutId as string | undefined;
  if (!familyId || !cashOutId) {
    throw new HttpsError("invalid-argument", "familyId e cashOutId são obrigatórios.");
  }

  const db = getFirestore();
  await assertGuardian(db, familyId, uid);
  try {
    return await approveCashOutTx(db, { familyId, cashOutId, deciderUid: uid });
  } catch (error) {
    if (error instanceof CashOutError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }
});
