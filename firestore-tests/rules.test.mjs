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
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

let testEnv;

const FAMILY = 'fam1';
const GUARDIAN = 'guardian-1';
const CHILD = 'child-1';
const OUTSIDER = 'outsider-9';

function guardianDb() {
  return testEnv.authenticatedContext(GUARDIAN).firestore();
}
function childDb() {
  return testEnv.authenticatedContext(CHILD).firestore();
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

// O cliente só pode criar ajuste manual; earn/redeem vêm das Functions.
const validLedger = {
  memberId: 'm1',
  type: 'adjustment',
  points: 10,
  sourceType: 'manual',
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
  // Semeia a família + uma criança vinculada (CHILD) e docs com memberUid,
  // ignorando as regras.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'families', FAMILY), {
      name: 'Silva',
      guardianUids: [GUARDIAN],
      guardians: [{ uid: GUARDIAN, displayName: 'Ana' }],
      childUids: [CHILD],
      timezone: 'America/Sao_Paulo',
    });
    await setDoc(doc(db, `families/${FAMILY}/members/m-bia`), {
      type: 'child',
      displayName: 'Bia',
      linkedUid: CHILD,
    });
    await setDoc(doc(db, `families/${FAMILY}/members/m-leo`), {
      type: 'child',
      displayName: 'Léo',
    });
    await setDoc(doc(db, `families/${FAMILY}/tasks/t1`), validTask);
    await setDoc(doc(db, `families/${FAMILY}/rewards/r1`), {
      title: 'Cinema',
      cost: 100,
      active: true,
      stock: null,
    });
    await setDoc(doc(db, `families/${FAMILY}/taskInstances/ti-bia`), {
      taskId: 't1',
      memberId: 'm-bia',
      memberUid: CHILD,
      status: 'pending',
      requiresApproval: true,
    });
    await setDoc(doc(db, `families/${FAMILY}/taskInstances/ti-leo`), {
      taskId: 't1',
      memberId: 'm-leo',
      memberUid: 'uid-leo',
      status: 'pending',
      requiresApproval: true,
    });
    await setDoc(doc(db, `families/${FAMILY}/ledger/earn__a`), {
      memberId: 'm-bia',
      memberUid: CHILD,
      type: 'earn',
      points: 10,
      sourceType: 'taskInstance',
    });
    await setDoc(doc(db, `families/${FAMILY}/ledger/earn__b`), {
      memberId: 'm-leo',
      memberUid: 'uid-leo',
      type: 'earn',
      points: 5,
      sourceType: 'taskInstance',
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
      guardians: [{ uid: GUARDIAN, displayName: 'Ana' }],
      timezone: 'America/Sao_Paulo',
    }),
  );
  await assertFails(
    addDoc(collection(guardianDb(), 'families'), {
      name: 'Alheia',
      guardianUids: ['outro'],
      guardians: [{ uid: 'outro', displayName: 'X' }],
      timezone: 'America/Sao_Paulo',
    }),
  );
  // sem o campo guardians -> rejeitado
  await assertFails(
    addDoc(collection(guardianDb(), 'families'), {
      name: 'Sem guardians',
      guardianUids: [GUARDIAN],
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

test('tarefa: description null é aceito; string longa demais não', async () => {
  const tasks = collection(guardianDb(), `families/${FAMILY}/tasks`);
  await assertSucceeds(addDoc(tasks, { ...validTask, description: null }));
  await assertFails(addDoc(tasks, { ...validTask, description: 'x'.repeat(501) }));
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

test('ledger: cliente não pode criar earn nem redeem (só a Function)', async () => {
  const ledger = collection(guardianDb(), `families/${FAMILY}/ledger`);
  await assertFails(addDoc(ledger, { ...validLedger, type: 'earn', sourceType: 'taskInstance' }));
  await assertFails(addDoc(ledger, { ...validLedger, type: 'redeem', points: -10, sourceType: 'reward' }));
});

test('redemptions: cliente não cria, mas marca como entregue', async () => {
  const col = `families/${FAMILY}/redemptions`;
  // semeia como a Function faria
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `${col}/red1`), {
      rewardId: 'r1',
      memberId: 'm1',
      cost: 50,
      status: 'requested',
    });
  });

  const ref = doc(guardianDb(), `${col}/red1`);
  await assertSucceeds(getDoc(ref));
  await assertFails(
    setDoc(doc(guardianDb(), `${col}/red2`), { rewardId: 'r', memberId: 'm', cost: 1, status: 'requested' }),
  );
  await assertSucceeds(updateDoc(ref, { status: 'delivered' }));
  // não pode alterar o custo
  await assertFails(updateDoc(ref, { cost: 1 }));
});

test('taskInstances: responsável muda status, mas não pointsAwarded nem pula para approved', async () => {
  const col = `families/${FAMILY}/taskInstances`;
  const ref = doc(guardianDb(), `${col}/i1`);

  await assertSucceeds(
    setDoc(ref, {
      taskId: 't1',
      memberId: 'm1',
      status: 'pending',
      requiresApproval: true,
    }),
  );

  // pending -> awaitingApproval: ok
  await assertSucceeds(updateDoc(ref, { status: 'awaitingApproval' }));

  // cliente não pode gravar pointsAwarded
  await assertFails(updateDoc(ref, { pointsAwarded: 10 }));

  // awaitingApproval -> approved: ok
  await assertSucceeds(updateDoc(ref, { status: 'approved' }));

  // pending -> approved direto (exige aprovação): negado
  const ref2 = doc(guardianDb(), `${col}/i2`);
  await assertSucceeds(
    setDoc(ref2, { taskId: 't1', memberId: 'm1', status: 'pending', requiresApproval: true }),
  );
  await assertFails(updateDoc(ref2, { status: 'approved' }));

  // pending -> approved quando NÃO exige aprovação: ok
  const ref3 = doc(guardianDb(), `${col}/i3`);
  await assertSucceeds(
    setDoc(ref3, { taskId: 't1', memberId: 'm1', status: 'pending', requiresApproval: false }),
  );
  await assertSucceeds(updateDoc(ref3, { status: 'approved' }));
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

test('fcmTokens: cada um só os próprios', async () => {
  await assertSucceeds(
    setDoc(doc(guardianDb(), `users/${GUARDIAN}/fcmTokens/tok1`), { platform: 'web' }),
  );
  await assertFails(
    setDoc(doc(guardianDb(), `users/${OUTSIDER}/fcmTokens/tok2`), { platform: 'web' }),
  );
  await assertFails(getDoc(doc(outsiderDb(), `users/${GUARDIAN}/fcmTokens/tok1`)));
});

// ---- papel "criança" (issues #33/#34) ----------------------------------

test('criança lê a própria família e a lista por childUids', async () => {
  await assertSucceeds(getDoc(doc(childDb(), 'families', FAMILY)));
  await assertSucceeds(
    getDocs(
      query(
        collection(childDb(), 'families'),
        where('childUids', 'array-contains', CHILD),
      ),
    ),
  );
  // estranho continua barrado
  await assertFails(getDoc(doc(outsiderDb(), 'families', FAMILY)));
});

test('criança lê members/tasks/rewards, mas não escreve', async () => {
  await assertSucceeds(getDoc(doc(childDb(), `families/${FAMILY}/members/m-leo`)));
  await assertSucceeds(getDoc(doc(childDb(), `families/${FAMILY}/tasks/t1`)));
  await assertSucceeds(getDoc(doc(childDb(), `families/${FAMILY}/rewards/r1`)));

  await assertFails(addDoc(collection(childDb(), `families/${FAMILY}/tasks`), validTask));
  await assertFails(
    updateDoc(doc(childDb(), `families/${FAMILY}/members/m-bia`), { displayName: 'X' }),
  );
  await assertFails(
    updateDoc(doc(childDb(), `families/${FAMILY}/rewards/r1`), { cost: 1 }),
  );
});

test('criança lê a própria taskInstance, não a do irmão', async () => {
  await assertSucceeds(
    getDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-bia`)),
  );
  await assertFails(
    getDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-leo`)),
  );
});

test('criança: query de taskInstances precisa filtrar por memberUid', async () => {
  const col = collection(childDb(), `families/${FAMILY}/taskInstances`);
  await assertSucceeds(getDocs(query(col, where('memberUid', '==', CHILD))));
  await assertFails(getDocs(query(col, where('memberId', '==', 'm-bia'))));
  await assertFails(getDocs(col));
});

test('criança marca a própria tarefa: pending -> awaitingApproval', async () => {
  await assertSucceeds(
    updateDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-bia`), {
      status: 'awaitingApproval',
      completedAt: new Date(),
    }),
  );
});

test('criança limpa o rejectionReason ao refazer uma tarefa recusada', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `families/${FAMILY}/taskInstances/ti-redo`), {
      taskId: 't1',
      memberId: 'm-bia',
      memberUid: CHILD,
      status: 'pending',
      requiresApproval: true,
      rejectionReason: 'a cama ainda está bagunçada',
    });
  });
  await assertSucceeds(
    updateDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-redo`), {
      status: 'awaitingApproval',
      completedAt: new Date(),
      rejectionReason: null,
    }),
  );
});

test('criança não pula para approved quando a tarefa exige aprovação', async () => {
  await assertFails(
    updateDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-bia`), {
      status: 'approved',
    }),
  );
});

test('criança pode -> approved quando a tarefa não exige aprovação', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `families/${FAMILY}/taskInstances/ti-free`), {
      taskId: 't1',
      memberId: 'm-bia',
      memberUid: CHILD,
      status: 'pending',
      requiresApproval: false,
    });
  });
  await assertSucceeds(
    updateDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-free`), {
      status: 'approved',
    }),
  );
});

test('criança não grava pointsAwarded nem reviewedByUid; não marca a do irmão', async () => {
  const ref = doc(childDb(), `families/${FAMILY}/taskInstances/ti-bia`);
  await assertFails(updateDoc(ref, { status: 'awaitingApproval', pointsAwarded: 10 }));
  await assertFails(updateDoc(ref, { status: 'awaitingApproval', reviewedByUid: CHILD }));
  await assertFails(updateDoc(ref, { status: 'awaitingApproval', memberUid: 'outro' }));
  await assertFails(
    updateDoc(doc(childDb(), `families/${FAMILY}/taskInstances/ti-leo`), {
      status: 'awaitingApproval',
    }),
  );
});

test('criança lê o próprio ledger, não o do irmão; não cria entrada', async () => {
  await assertSucceeds(
    getDocs(
      query(
        collection(childDb(), `families/${FAMILY}/ledger`),
        where('memberUid', '==', CHILD),
      ),
    ),
  );
  await assertFails(getDoc(doc(childDb(), `families/${FAMILY}/ledger/earn__b`)));
  await assertFails(
    addDoc(collection(childDb(), `families/${FAMILY}/ledger`), {
      ...validLedger,
      memberUid: CHILD,
    }),
  );
});

test('criança não edita a família', async () => {
  await assertFails(
    updateDoc(doc(childDb(), 'families', FAMILY), { name: 'Nova' }),
  );
});
