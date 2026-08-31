// Testes de geração de ocorrências contra o emulador do Firestore.
//   firebase emulators:exec --only firestore "npm --prefix functions run test:integration"
// ou, com o emulador de pé:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 node --test "test/generate.test.mjs"

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";

import { generateForFamily } from "../lib/tasks/generate.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
let familyId;

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});

after(async () => {
  await db.terminate();
});

async function wipe() {
  const families = await db.collection("families").get();
  for (const f of families.docs) {
    for (const sub of ["tasks", "members", "taskInstances"]) {
      const docs = await f.ref.collection(sub).get();
      await Promise.all(docs.docs.map((d) => d.ref.delete()));
    }
    await f.ref.delete();
  }
}

beforeEach(async () => {
  await wipe();
  const family = await db.collection("families").add({
    name: "Silva",
    guardianUids: ["g1"],
    timezone: "America/Sao_Paulo",
  });
  familyId = family.id;
  await family.collection("members").add({ type: "child", displayName: "Bia" });
  await family.collection("members").add({ type: "child", displayName: "Léo" });
});

function dailyTask(overrides = {}) {
  return {
    title: "Arrumar a cama",
    points: 10,
    category: "routine",
    assigneeMemberId: null,
    requiresApproval: true,
    active: true,
    recurrence: {
      type: "daily",
      daysOfWeek: [],
      startDate: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
      endDate: null,
    },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    ...overrides,
  };
}

test("gera uma ocorrência por criança para tarefa diária sem responsável", async () => {
  await db.collection(`families/${familyId}/tasks`).add(dailyTask());
  const now = new Date("2026-08-11T14:00:00Z"); // 11h em SP -> dia 2026-08-11

  const result = await generateForFamily(db, familyId, { now });
  assert.equal(result.created, 2);
  assert.equal(result.dateStr, "2026-08-11");

  const instances = await db.collection(`families/${familyId}/taskInstances`).get();
  assert.equal(instances.size, 2);
  assert.ok(instances.docs.every((d) => d.data().status === "pending"));
  assert.ok(instances.docs.every((d) => d.data().pointsSnapshot === 10));
});

test("idempotente: rodar de novo não duplica", async () => {
  await db.collection(`families/${familyId}/tasks`).add(dailyTask());
  const now = new Date("2026-08-11T14:00:00Z");

  await generateForFamily(db, familyId, { now });
  const second = await generateForFamily(db, familyId, { now });

  assert.equal(second.created, 0);
  const instances = await db.collection(`families/${familyId}/taskInstances`).get();
  assert.equal(instances.size, 2);
});

test("tarefa com responsável específico gera só para ele", async () => {
  const children = await db.collection(`families/${familyId}/members`).get();
  const biaId = children.docs.find((d) => d.data().displayName === "Bia").id;
  await db
    .collection(`families/${familyId}/tasks`)
    .add(dailyTask({ assigneeMemberId: biaId }));

  const result = await generateForFamily(db, familyId, {
    now: new Date("2026-08-11T14:00:00Z"),
  });
  assert.equal(result.created, 1);
  const instances = await db.collection(`families/${familyId}/taskInstances`).get();
  assert.equal(instances.docs[0].data().memberId, biaId);
});

test("weekly só gera no dia da semana certo", async () => {
  await db.collection(`families/${familyId}/tasks`).add(
    dailyTask({
      recurrence: {
        type: "weekly",
        daysOfWeek: [1], // segunda
        startDate: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
        endDate: null,
      },
    }),
  );

  // 2026-08-11 é terça -> nada
  const tue = await generateForFamily(db, familyId, {
    now: new Date("2026-08-11T14:00:00Z"),
  });
  assert.equal(tue.created, 0);

  // 2026-08-10 é segunda -> 2 (uma por criança)
  const mon = await generateForFamily(db, familyId, {
    now: new Date("2026-08-10T14:00:00Z"),
  });
  assert.equal(mon.created, 2);
});

test("tarefa arquivada não gera", async () => {
  await db.collection(`families/${familyId}/tasks`).add(dailyTask({ active: false }));
  const result = await generateForFamily(db, familyId, {
    now: new Date("2026-08-11T14:00:00Z"),
  });
  assert.equal(result.created, 0);
});
