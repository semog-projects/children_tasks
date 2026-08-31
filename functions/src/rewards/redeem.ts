import { FieldValue, Firestore } from "firebase-admin/firestore";

/** Erro de regra de negócio no resgate. `code` vira o code do HttpsError. */
export class RedeemError extends Error {
  constructor(
    readonly code: "not-found" | "failed-precondition" | "permission-denied",
    message: string,
  ) {
    super(message);
  }
}

export interface RedeemResult {
  redemptionId: string;
  cost: number;
  newBalance: number;
}

export interface RedeemTarget {
  memberId: string;
  /** `linkedUid` da criança (quando tem login) — gravado em redemption/ledger. */
  memberUid: string | null;
}

/**
 * Descobre para qual criança é o resgate e o `memberUid` a gravar (#35):
 * - **responsável** resgata para qualquer criança (`requestedMemberId`);
 * - **criança** resgata só para si — ignora `requestedMemberId` e usa o
 *   `member` vinculado à conta.
 */
export async function resolveRedeemTarget(
  db: Firestore,
  familyId: string,
  callerUid: string,
  requestedMemberId: string | undefined,
): Promise<RedeemTarget> {
  const family = (await db.doc(`families/${familyId}`).get()).data() ?? {};
  const guardianUids = (family.guardianUids ?? []) as string[];
  const childUids = (family.childUids ?? []) as string[];

  if (guardianUids.includes(callerUid)) {
    if (!requestedMemberId) {
      throw new RedeemError("failed-precondition", "memberId é obrigatório.");
    }
    const member = await db
      .doc(`families/${familyId}/members/${requestedMemberId}`)
      .get();
    return {
      memberId: requestedMemberId,
      memberUid: (member.data()?.linkedUid as string | undefined) ?? null,
    };
  }

  if (childUids.includes(callerUid)) {
    const snap = await db
      .collection(`families/${familyId}/members`)
      .where("linkedUid", "==", callerUid)
      .limit(1)
      .get();
    if (snap.empty) {
      throw new RedeemError(
        "permission-denied",
        "Conta não vinculada a uma criança.",
      );
    }
    return { memberId: snap.docs[0].id, memberUid: callerUid };
  }

  throw new RedeemError(
    "permission-denied",
    "Você não faz parte desta família.",
  );
}

/**
 * Resgata uma recompensa para uma criança, de forma transacional:
 * checa saldo (não deixa negativo) e estoque, debita os pontos no `ledger`
 * (`redeem__{redemptionId}`) e cria o registro de resgate (`requested`).
 */
export async function redeemReward(
  db: Firestore,
  params: {
    familyId: string;
    rewardId: string;
    memberId: string;
    memberUid?: string | null;
    requestedByUid: string;
  },
): Promise<RedeemResult> {
  const { familyId, rewardId, memberId, memberUid, requestedByUid } = params;
  const rewardRef = db.doc(`families/${familyId}/rewards/${rewardId}`);
  const ledgerCol = db.collection(`families/${familyId}/ledger`);
  const redemptionRef = db.collection(`families/${familyId}/redemptions`).doc();

  return db.runTransaction(async (tx) => {
    const rewardSnap = await tx.get(rewardRef);
    if (!rewardSnap.exists) {
      throw new RedeemError("not-found", "Recompensa não encontrada.");
    }
    const reward = rewardSnap.data() as Record<string, unknown>;
    if (reward.active === false) {
      throw new RedeemError("failed-precondition", "Recompensa inativa.");
    }
    const cost = (reward.cost as number | undefined) ?? 0;
    if (cost <= 0) {
      throw new RedeemError("failed-precondition", "Recompensa sem custo válido.");
    }

    const stock = reward.stock as number | null | undefined;
    if (stock != null && stock <= 0) {
      throw new RedeemError("failed-precondition", "Recompensa sem estoque.");
    }

    const ledgerSnap = await tx.get(ledgerCol.where("memberId", "==", memberId));
    const balance = ledgerSnap.docs.reduce(
      (sum, d) => sum + ((d.data().points as number | undefined) ?? 0),
      0,
    );
    if (balance < cost) {
      throw new RedeemError("failed-precondition", "Saldo insuficiente.");
    }

    const memberUidField = memberUid ? { memberUid } : {};
    tx.set(ledgerCol.doc(`redeem__${redemptionRef.id}`), {
      memberId,
      ...memberUidField,
      type: "redeem",
      points: -cost,
      sourceType: "reward",
      sourceId: redemptionRef.id,
      createdByUid: requestedByUid,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(redemptionRef, {
      rewardId,
      memberId,
      ...memberUidField,
      rewardTitleSnapshot: (reward.title as string | undefined) ?? "",
      cost,
      status: "requested",
      requestedByUid,
      requestedAt: FieldValue.serverTimestamp(),
    });
    if (stock != null) {
      tx.update(rewardRef, {
        stock: stock - 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return { redemptionId: redemptionRef.id, cost, newBalance: balance - cost };
  });
}
