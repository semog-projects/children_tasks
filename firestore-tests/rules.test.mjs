// Testes das Security Rules do Firestore (issue #6).
//
// Requer o emulador do Firestore rodando. Rode via:
//   firebase emulators:exec --only firestore "npm --prefix firestore-tests test"
//
// Ou, com o emulador já de pé:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 npm --prefix firestore-tests test

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let testEnv;

const FAMILY = 'fam1';
const GUARDIAN = 'guardian-1';
const OUTSIDER = 'outsider-9';

function guardianDb() {
  return testEnv.authenticatedContext(GUARDIAN).firestore();
}
function outsiderDb() {
  return testEnv.authenticatedContext(OUTSIDER).firestore();
}
function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

const validTask = {
  title: 'Arrumar a cama',
  points: 10,
  category: 'routine',
  requiresApproval: true,
  active: true,
  assigneeMemberId: null,
  recurrence: { type: 'daily', daysOfWeek: [], startDate: new Date(), endDate: null },
};

const validLedger = {
  memberId: 'm1',
  type: 'earn',
  points: 10,
  sourceType: 'taskInstance',
  createdByUid: GUARDIAN,
};

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT ?? 'demo-children-tasks',
    firestore: {
      rules: readFileSync(
        fileURLToPath(new URL('../firestore.rules', import.meta.url)),
        'utf8',
      ),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Semeia a família com o GUARDIAN como responsável, ignorando as regras.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'families', FAMILY), {
      name: 'Silva',
      guardianUids: [GUARDIAN],
      timezone: 'America/Sao_Paulo',
    });
  });
});

test('responsável lê a própria família; estranho e anônimo não', async () => {
  await assertSucceeds(getDoc(doc(guardianDb(), 'families', FAMILY)));
  await assertFails(getDoc(doc(outsiderDb(), 'families', FAMILY)));
  await assertFails(getDoc(doc(anonDb(), 'families', FAMILY)));
});

test('criar família exige o próprio uid em guardianUids', async () => {
  await assertSucceeds(
    addDoc(collection(guardianDb(), 'families'), {
      name: 'Nova',
      guardianUids: [GUARDIAN],
      timezone: 'America/Sao_Paulo',
    }),
  );
  await assertFails(
    addDoc(collection(guardianDb(), 'families'), {
      name: 'Alheia',
      guardianUids: ['outro'],
      timezone: 'America/Sao_Paulo',
    }),
  );
});

test('família não pode ser deletada pelo cliente', async () => {
  await assertFails(deleteDoc(doc(guardianDb(), 'families', FAMILY)));
});

test('responsável faz CRUD de tarefas; estranho não', async () => {
  const guardianTasks = collection(guardianDb(), `families/${FAMILY}/tasks`);
  const ref = await assertSucceeds(addDoc(guardianTasks, validTask));
  await assertSucceeds(updateDoc(ref, { points: 20 }));
  await assertSucceeds(getDoc(ref));

  await assertFails(
    addDoc(collection(outsiderDb(), `families/${FAMILY}/tasks`), validTask),
  );
});

test('tarefa: pontos <= 0 e categoria inválida são rejeitados', async () => {
  const tasks = collection(guardianDb(), `families/${FAMILY}/tasks`);
  await assertFails(addDoc(tasks, { ...validTask, points: 0 }));
  await assertFails(addDoc(tasks, { ...validTask, points: -5 }));
  await assertFails(addDoc(tasks, { ...validTask, category: 'inventada' }));
});

test('ledger: responsável cria, mas não atualiza nem deleta', async () => {
  const ledger = collection(guardianDb(), `families/${FAMILY}/ledger`);
  const ref = await assertSucceeds(addDoc(ledger, validLedger));
  await assertFails(updateDoc(ref, { points: 999 }));
  await assertFails(deleteDoc(ref));
});

test('ledger: points = 0 e createdByUid diferente do auth são rejeitados', async () => {
  const ledger = collection(guardianDb(), `families/${FAMILY}/ledger`);
  await assertFails(addDoc(ledger, { ...validLedger, points: 0 }));
  await assertFails(addDoc(ledger, { ...validLedger, createdByUid: 'alguem' }));
});

test('membros/recompensas/instâncias: estranho não acessa', async () => {
  for (const sub of ['members', 'rewards', 'taskInstances']) {
    await assertFails(
      getDoc(doc(outsiderDb(), `families/${FAMILY}/${sub}/x`)),
    );
  }
});

test('users/{uid}: cada um só o próprio doc', async () => {
  await assertSucceeds(
    setDoc(doc(guardianDb(), 'users', GUARDIAN), { displayName: 'Ana' }),
  );
  await assertFails(
    setDoc(doc(guardianDb(), 'users', OUTSIDER), { displayName: 'Hack' }),
  );
});
