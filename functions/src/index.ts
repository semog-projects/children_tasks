/**
 * Cloud Functions do children_tasks.
 *
 * - generateDailyInstances: agendada, materializa as tarefas do dia (#10)
 * - generateInstances: callable, para o app forçar a geração ao abrir (#10)
 * - onTaskInstanceWritten: credita pontos no ledger ao aprovar (#11)
 *
 * Próxima: notificações FCM (#14).
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { generateAllFamilies, generateForFamily } from "./tasks/generate.js";
import { onInstanceStatusChange } from "./tasks/ledger.js";

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
      const snap = await db.collection("families").doc(familyId).get();
      if (!snap.exists || !(snap.data()?.guardianUids ?? []).includes(uid)) {
        throw new HttpsError("permission-denied", "Você não é responsável desta família.");
      }
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
 * Ao aprovar uma ocorrência (`status` -> `approved`), credita os pontos no
 * `ledger` de forma idempotente.
 */
export const onTaskInstanceWritten = onDocumentWritten(
  {
    document: "families/{familyId}/taskInstances/{instanceId}",
    region: REGION,
  },
  async (event) => {
    const { familyId, instanceId } = event.params;
    await onInstanceStatusChange(
      getFirestore(),
      familyId,
      instanceId,
      event.data?.before.data(),
      event.data?.after.data(),
    );
  },
);
