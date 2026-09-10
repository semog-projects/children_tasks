// Câmbio de pontos por dinheiro (issue #66). Requer o emulador.

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

import {
  approveCashOut,
  CashOutError,
  requestCashOut,
} from "../lib/cashout/cashout.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
const FAMILY = "fam-cashout";

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

async function wipe() {
  for (const sub of ["ledger", "cashOuts", "members"]) {
    const docs = await db.collection(`families/${FAMILY}/${sub}`).get();
    await Promise.all(docs.docs.map((d) => d.ref.delete()));
  }
  await db.doc(`families/${FAMILY}`).set({
    name: "Silva",
    guardianUids: ["g1"],
    childUids: ["uid-bia"],
    pointValueCents: 1.6,
  });
  await db.doc(`families/${FAMILY}/members/m1`).set({
    type: "child",
    displayName: "Bia",
    linkedUid: "uid-bia",
  });
}

async function seedBalance(memberId, points) {
  await db.collection(`families/${FAMILY}/ledger`).add({
    memberId,
    type: "earn",
    points,
    sourceType: "taskInstance",
    createdByUid: "system",
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function balance(memberId) {
  const snap = await db
    .collection(`families/${FAMILY}/ledger`)
    .where("memberId", "==", memberId)
    .get();
  return snap.docs.reduce((s, d) => s + d.data().points, 0);
}

beforeEach(wipe);

const req = (over = {}) => ({
  familyId: FAMILY,
  memberId: "m1",
  memberUid: "uid-bia",
  points: 125,
  requestedByUid: "uid-bia",
  ...over,
});

test("requestCashOut cria o pedido sem mexer no saldo", async () => {
  await seedBalance("m1", 200);
  const result = await requestCashOut(db, req());

  assert.equal(result.points, 125);
  assert.equal(result.amountCents, 200); // 125 * 1.6
  assert.equal(await balance("m1"), 200); // intacto

  const doc = await db.doc(`families/${FAMILY}/cashOuts/${result.cashOutId}`).get();
  assert.equal(doc.data().status, "requested");
  assert.equal(doc.data().rateCents, 1.6);
  assert.equal(doc.data().memberUid, "uid-bia");
});

test("requestCashOut recusa pontos que não são múltiplos de 5", async () => {
  await seedBalance("m1", 200);
  await assert.rejects(
    () => requestCashOut(db, req({ points: 123 })),
    (e) => e instanceof CashOutError && e.code === "failed-precondition",
  );
});

test("requestCashOut recusa pontos <= 0", async () => {
  await seedBalance("m1", 200);
  await assert.rejects(() => requestCashOut(db, req({ points: 0 })), CashOutError);
});

test("requestCashOut recusa saldo insuficiente", async () => {
  await seedBalance("m1", 100);
  await assert.rejects(() => requestCashOut(db, req()), CashOutError);
});

test("approveCashOut debita transacionalmente e marca approved", async () => {
  await seedBalance("m1", 200);
  const { cashOutId } = await requestCashOut(db, req());

  const result = await approveCashOut(db, {
    familyId: FAMILY,
    cashOutId,
    deciderUid: "g1",
  });
  assert.equal(result.newBalance, 75);
  assert.equal(await balance("m1"), 75);

  const doc = await db.doc(`families/${FAMILY}/cashOuts/${cashOutId}`).get();
  assert.equal(doc.data().status, "approved");
  assert.equal(doc.data().decidedByUid, "g1");

  const debit = (
    await db
      .collection(`families/${FAMILY}/ledger`)
      .where("type", "==", "redeem")
      .get()
  ).docs[0].data();
  assert.equal(debit.points, -125);
  assert.equal(debit.sourceType, "cashOut");
  assert.equal(debit.memberUid, "uid-bia");
});

test("approveCashOut recusa se o saldo caiu abaixo desde o pedido", async () => {
  await seedBalance("m1", 130);
  const { cashOutId } = await requestCashOut(db, req());
  await seedBalance("m1", -20); // saldo agora 110 < 125

  await assert.rejects(
    () => approveCashOut(db, { familyId: FAMILY, cashOutId, deciderUid: "g1" }),
    CashOutError,
  );
  assert.equal(await balance("m1"), 110);
});

test("approveCashOut não aprova duas vezes", async () => {
  await seedBalance("m1", 400);
  const { cashOutId } = await requestCashOut(db, req());
  await approveCashOut(db, { familyId: FAMILY, cashOutId, deciderUid: "g1" });

  await assert.rejects(
    () => approveCashOut(db, { familyId: FAMILY, cashOutId, deciderUid: "g1" }),
    (e) => e instanceof CashOutError && e.code === "failed-precondition",
  );
  assert.equal(await balance("m1"), 275);
});

test("requestCashOut usa a cotação da família (default 1.6 sem o campo)", async () => {
  await db.doc(`families/${FAMILY}`).set(
    { name: "Silva", guardianUids: ["g1"], childUids: ["uid-bia"] },
    { merge: false },
  );
  await seedBalance("m1", 200);
  const { amountCents } = await requestCashOut(db, req({ points: 100 }));
  assert.equal(amountCents, 160);
});
