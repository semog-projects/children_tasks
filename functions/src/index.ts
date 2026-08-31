/**
 * Cloud Functions do children_tasks.
 *
 * Ainda sem funções: o scaffold (build TypeScript, admin SDK, deploy,
 * emulador) fica pronto aqui. As primeiras funções chegam com:
 *  - issue #10: geração de tarefas recorrentes (agendada);
 *  - issue #11: crédito transacional de pontos na aprovação;
 *  - issue #14: disparo de notificações (FCM).
 */

import { initializeApp } from "firebase-admin/app";

initializeApp();

// Exporte as funções aqui conforme forem criadas, ex.:
// export { generateRecurringTasks } from "./tasks/generate-recurring";
