import { FieldValue, Firestore } from "firebase-admin/firestore";

/** Erro de regra de negócio no resgate. `code` vira o code do HttpsError. */
export class RedeemError extends Error {
  constructor(
    readonly code: "not-found" | "failed-precondition",
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
    requestedByUid: string;
  },
): Promise<RedeemResult> {
  const { familyId, rewardId, memberId, requestedByUid } = params;
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

    tx.set(ledgerCol.doc(`redeem__${redemptionRef.id}`), {
      memberId,
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
