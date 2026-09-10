import { FieldValue, Firestore } from "firebase-admin/firestore";

/** Erro de regra de negócio no câmbio. `code` vira o code do HttpsError. */
export class CashOutError extends Error {
  constructor(
    readonly code: "not-found" | "failed-precondition" | "permission-denied",
    message: string,
  ) {
    super(message);
  }
}

/** Troca sempre em múltiplos de 5 pontos (centavo redondo). */
export const CASH_OUT_POINTS_STEP = 5;

/** Cotação padrão: R$ 0,016 por ponto (100 pts = R$ 1,60). */
const DEFAULT_RATE_CENTS = 1.6;

async function familyRateCents(db: Firestore, familyId: string): Promise<number> {
  const fam = (await db.doc(`families/${familyId}`).get()).data() ?? {};
  const raw = fam.pointValueCents as number | undefined;
  return typeof raw === "number" && raw > 0 ? raw : DEFAULT_RATE_CENTS;
}

async function memberBalance(
  db: Firestore,
  familyId: string,
  memberId: string,
): Promise<number> {
  const snap = await db
    .collection(`families/${familyId}/ledger`)
    .where("memberId", "==", memberId)
    .get();
  return snap.docs.reduce(
    (sum, d) => sum + ((d.data().points as number | undefined) ?? 0),
    0,
  );
}

export interface RequestCashOutResult {
  cashOutId: string;
  points: number;
  amountCents: number;
}

/**
 * Cria um pedido de câmbio (`requested`). NÃO mexe no saldo — o débito é
 * transacional na aprovação (`approveCashOut`).
 */
export async function requestCashOut(
  db: Firestore,
  params: {
    familyId: string;
    memberId: string;
    memberUid?: string | null;
    points: number;
    requestedByUid: string;
  },
): Promise<RequestCashOutResult> {
  const { familyId, memberId, memberUid, points, requestedByUid } = params;

  if (!Number.isInteger(points) || points <= 0) {
    throw new CashOutError("failed-precondition", "Quantidade de pontos inválida.");
  }
  if (points % CASH_OUT_POINTS_STEP !== 0) {
    throw new CashOutError(
      "failed-precondition",
      `A troca é em múltiplos de ${CASH_OUT_POINTS_STEP} pontos.`,
    );
  }

  const balance = await memberBalance(db, familyId, memberId);
  if (balance < points) {
    throw new CashOutError("failed-precondition", "Saldo insuficiente.");
  }

  const rateCents = await familyRateCents(db, familyId);
  const amountCents = Math.round(points * rateCents);
  const ref = db.collection(`families/${familyId}/cashOuts`).doc();

  await ref.set({
    memberId,
    ...(memberUid ? { memberUid } : {}),
    points,
    amountCents,
    rateCents,
    status: "requested",
    requestedByUid,
    requestedAt: FieldValue.serverTimestamp(),
  });

  return { cashOutId: ref.id, points, amountCents };
}

export interface ApproveCashOutResult {
  points: number;
  newBalance: number;
}

/**
 * Aprova um pedido `requested`: transação que recheca o saldo (nunca deixa
 * negativo), debita os pontos no `ledger` (`cashout__{id}`) e marca `approved`.
 */
export async function approveCashOut(
  db: Firestore,
  params: { familyId: string; cashOutId: string; deciderUid: string },
): Promise<ApproveCashOutResult> {
  const { familyId, cashOutId, deciderUid } = params;
  const cashOutRef = db.doc(`families/${familyId}/cashOuts/${cashOutId}`);
  const ledgerCol = db.collection(`families/${familyId}/ledger`);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(cashOutRef);
    if (!snap.exists) {
      throw new CashOutError("not-found", "Pedido não encontrado.");
    }
    const data = snap.data() as Record<string, unknown>;
    if (data.status !== "requested") {
      throw new CashOutError("failed-precondition", "Este pedido já foi decidido.");
    }

    const points = (data.points as number | undefined) ?? 0;
    const memberId = data.memberId as string;
    const memberUid = data.memberUid as string | undefined;

    const ledgerSnap = await tx.get(ledgerCol.where("memberId", "==", memberId));
    const balance = ledgerSnap.docs.reduce(
      (sum, d) => sum + ((d.data().points as number | undefined) ?? 0),
      0,
    );
    if (balance < points) {
      throw new CashOutError("failed-precondition", "Saldo insuficiente.");
    }

    tx.set(ledgerCol.doc(`cashout__${cashOutId}`), {
      memberId,
      ...(memberUid ? { memberUid } : {}),
      type: "redeem",
      points: -points,
      sourceType: "cashOut",
      sourceId: cashOutId,
      createdByUid: deciderUid,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(cashOutRef, {
      status: "approved",
      decidedByUid: deciderUid,
      decidedAt: FieldValue.serverTimestamp(),
    });

    return { points, newBalance: balance - points };
  });
}
