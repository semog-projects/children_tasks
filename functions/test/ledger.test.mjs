// Crédito de pontos na aprovação (issue #11). Requer o emulador do Firestore.

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { onInstanceStatusChange } from "../lib/tasks/ledger.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
const FAMILY = "fam1";
const INSTANCE = "inst1";

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

beforeEach(async () => {
  const ledger = await db.collection(`families/${FAMILY}/ledger`).get();
  await Promise.all(ledger.docs.map((d) => d.ref.delete()));
  await db.doc(`families/${FAMILY}/taskInstances/${INSTANCE}`).set({
    memberId: "m1",
    status: "awaitingApproval",
    pointsSnapshot: 10,
  });
});

const approved = { status: "approved", memberId: "m1", pointsSnapshot: 10, reviewedByUid: "g1" };

test("aprovar credita os pontos no ledger", async () => {
  await onInstanceStatusChange(db, FAMILY, INSTANCE, { status: "awaitingApproval" }, approved);

  const ledger = await db.collection(`families/${FAMILY}/ledger`).get();
  assert.equal(ledger.size, 1);
  const entry = ledger.docs[0].data();
  assert.equal(entry.points, 10);
  assert.equal(entry.type, "earn");
  assert.equal(entry.sourceId, INSTANCE);
  assert.equal(ledger.docs[0].id, `earn__${INSTANCE}`);

  const inst = await db.doc(`families/${FAMILY}/taskInstances/${INSTANCE}`).get();
  assert.equal(inst.data().pointsAwarded, 10);
});

test("idempotente: aprovar de novo não credita duas vezes", async () => {
  await onInstanceStatusChange(db, FAMILY, INSTANCE, { status: "awaitingApproval" }, approved);
  await onInstanceStatusChange(db, FAMILY, INSTANCE, { status: "awaitingApproval" }, approved);
  // e uma escrita que não muda o status
  await onInstanceStatusChange(db, FAMILY, INSTANCE, approved, { ...approved, pointsAwarded: 10 });

  const ledger = await db.collection(`families/${FAMILY}/ledger`).get();
  assert.equal(ledger.size, 1);
});

test("sem transição para approved não credita", async () => {
  await onInstanceStatusChange(
    db,
    FAMILY,
    INSTANCE,
    { status: "pending" },
    { status: "awaitingApproval", memberId: "m1", pointsSnapshot: 10 },
  );
  const ledger = await db.collection(`families/${FAMILY}/ledger`).get();
  assert.equal(ledger.size, 0);
});
