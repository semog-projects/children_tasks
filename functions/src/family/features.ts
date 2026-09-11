import { Firestore } from "firebase-admin/firestore";

/** Nomes das funcionalidades toggleáveis — devem casar com `AppFeature` no app. */
export type Feature = "rewards" | "cashOut" | "investment" | "pointsAdjust";

const LABELS: Record<Feature, string> = {
  rewards: "As recompensas estão",
  cashOut: "A troca por dinheiro está",
  investment: "A poupança está",
  pointsAdjust: "O ajuste de pontos está",
};

/**
 * Lança se a família desligou [feature] (`family.disabledFeatures`, issue #75).
 * A mensagem vira o detail de um HttpsError `failed-precondition` no caller.
 */
export async function assertFeatureEnabled(
  db: Firestore,
  familyId: string,
  feature: Feature,
): Promise<void> {
  const fam = (await db.doc(`families/${familyId}`).get()).data() ?? {};
  const disabled = (fam.disabledFeatures ?? []) as string[];
  if (disabled.includes(feature)) {
    throw new FeatureDisabledError(
      `${LABELS[feature]} desativada pelos pais.`,
    );
  }
}

export class FeatureDisabledError extends Error {
  readonly code = "failed-precondition" as const;
}
