import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";

import { Lot, payoutNow } from "./yield.js";

/** Erro de regra de negócio na poupança. `code` vira o code do HttpsError. */
export class InvestmentError extends Error {
  constructor(
    readonly code: "not-found" | "failed-precondition" | "permission-denied",
    message: string,
  ) {
    super(message);
  }
}

const DEFAULT_WEEKLY_RATE_PCT = 2.0;
const DEFAULT_GRACE_DAYS = 7;

interface FamilyInvestmentConfig {
  weeklyRatePct: number;
  graceDays: number;
}

async function familyConfig(
  db: Firestore,
  familyId: string,
): Promise<FamilyInvestmentConfig> {
  const fam = (await db.doc(`families/${familyId}`).get()).data() ?? {};
  const rate = fam.investmentWeeklyRatePct as number | undefined;
  const grace = fam.investmentGraceDays as number | undefined;
  return {
    weeklyRatePct:
      typeof rate === "number" && rate > 0 ? rate : DEFAULT_WEEKLY_RATE_PCT,
    graceDays:
      typeof grace === "number" && grace >= 0 ? grace : DEFAULT_GRACE_DAYS,
  };
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

function lotsCol(db: Firestore, familyId: string, memberId: string) {
  return db.collection(`families/${familyId}/investments/${memberId}/lots`);
}

export interface RequestInvestmentResult {
  reqId: string;
  kind: "deposit" | "withdraw";
}

/**
 * Cria um pedido de aporte (`deposit`) ou resgate total (`withdraw`) na
 * poupança. NÃO mexe no saldo nem nos lotes — isso é na aprovação.
 */
export async function requestInvestment(
  db: Firestore,
  params: {
    familyId: string;
    memberId: string;
    memberUid?: string | null;
    kind: "deposit" | "withdraw";
    points?: number;
    requestedByUid: string;
  },
): Promise<RequestInvestmentResult> {
  const { familyId, memberId, memberUid, kind, points, requestedByUid } = params;

  if (kind !== "deposit" && kind !== "withdraw") {
    throw new InvestmentError("failed-precondition", "Tipo de pedido inválido.");
  }

  if (kind === "deposit") {
    if (!Number.isInteger(points) || (points as number) <= 0) {
      throw new InvestmentError(
        "failed-precondition",
        "Quantidade de pontos inválida.",
      );
    }
    const balance = await memberBalance(db, familyId, memberId);
    if (balance < (points as number)) {
      throw new InvestmentError("failed-precondition", "Saldo insuficiente.");
    }
  } else {
    const lots = await lotsCol(db, familyId, memberId).limit(1).get();
    if (lots.empty) {
      throw new InvestmentError(
        "failed-precondition",
        "Não há nada investido para resgatar.",
      );
    }
  }

  const ref = db.collection(`families/${familyId}/investmentRequests`).doc();
  await ref.set({
    memberId,
    ...(memberUid ? { memberUid } : {}),
    kind,
    ...(kind === "deposit" ? { points } : {}),
    status: "requested",
    requestedByUid,
    requestedAt: FieldValue.serverTimestamp(),
  });

  return { reqId: ref.id, kind };
}

export interface ApproveInvestmentResult {
  kind: "deposit" | "withdraw";
  points: number;
  payoutPoints?: number;
  yieldPoints?: number;
  newBalance: number;
}

/**
 * Aprova um pedido `requested`, transacionalmente:
 * - `deposit`: rechecа o saldo, debita no ledger (`invest__{reqId}`) e cria o lote.
 * - `withdraw`: soma os lotes com o rendimento (carência aplicada por lote),
 *   credita no ledger (`divest__{reqId}`) e apaga todos os lotes.
 */
export async function approveInvestment(
  db: Firestore,
  params: { familyId: string; reqId: string; deciderUid: string },
): Promise<ApproveInvestmentResult> {
  const { familyId, reqId, deciderUid } = params;
  const reqRef = db.doc(`families/${familyId}/investmentRequests/${reqId}`);
  const ledgerCol = db.collection(`families/${familyId}/ledger`);
  const cfg = await familyConfig(db, familyId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(reqRef);
    if (!snap.exists) {
      throw new InvestmentError("not-found", "Pedido não encontrado.");
    }
    const req = snap.data() as Record<string, unknown>;
    if (req.status !== "requested") {
      throw new InvestmentError(
        "failed-precondition",
        "Este pedido já foi decidido.",
      );
    }
    const memberId = req.memberId as string;
    const memberUid = req.memberUid as string | undefined;
    const kind = req.kind as "deposit" | "withdraw";
    const uidField = memberUid ? { memberUid } : {};

    const ledgerSnap = await tx.get(
      ledgerCol.where("memberId", "==", memberId),
    );
    const balance = ledgerSnap.docs.reduce(
      (sum, d) => sum + ((d.data().points as number | undefined) ?? 0),
      0,
    );

    if (kind === "deposit") {
      const points = (req.points as number | undefined) ?? 0;
      if (balance < points) {
        throw new InvestmentError("failed-precondition", "Saldo insuficiente.");
      }
      tx.set(ledgerCol.doc(`invest__${reqId}`), {
        memberId,
        ...uidField,
        type: "redeem",
        points: -points,
        sourceType: "investment",
        sourceId: reqId,
        createdByUid: deciderUid,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(lotsCol(db, familyId, memberId).doc(), {
        points,
        ...uidField,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(reqRef, {
        status: "approved",
        decidedByUid: deciderUid,
        decidedAt: FieldValue.serverTimestamp(),
      });
      return {
        kind,
        points,
        newBalance: balance - points,
      };
    }

    // withdraw: lê todos os lotes (leitura DENTRO da transação)
    const lotDocs = await tx.get(lotsCol(db, familyId, memberId));
    if (lotDocs.empty) {
      throw new InvestmentError(
        "failed-precondition",
        "Não há nada investido para resgatar.",
      );
    }
    const nowMs = Timestamp.now().toMillis();
    const lots: Lot[] = lotDocs.docs.map((d) => {
      const data = d.data();
      const ts = data.createdAt as Timestamp | undefined;
      return {
        points: (data.points as number | undefined) ?? 0,
        since: ts ? ts.toMillis() : nowMs,
      };
    });
    const { payout, yield: yieldPoints } = payoutNow(
      lots,
      nowMs,
      cfg.weeklyRatePct,
      cfg.graceDays,
    );

    tx.set(ledgerCol.doc(`divest__${reqId}`), {
      memberId,
      ...uidField,
      type: "earn",
      points: payout,
      sourceType: "investment",
      sourceId: reqId,
      createdByUid: deciderUid,
      createdAt: FieldValue.serverTimestamp(),
    });
    for (const d of lotDocs.docs) tx.delete(d.ref);
    tx.update(reqRef, {
      status: "approved",
      decidedByUid: deciderUid,
      decidedAt: FieldValue.serverTimestamp(),
      payoutPoints: payout,
      yieldPoints,
    });
    return {
      kind,
      points: payout,
      payoutPoints: payout,
      yieldPoints,
      newBalance: balance + payout,
    };
  });
}
