// Poupança que rende (issue #73). Requer o emulador.

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";

import {
  approveInvestment,
  InvestmentError,
  requestInvestment,
} from "../lib/investment/investment.js";
import { grossYield } from "../lib/investment/yield.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
const FAMILY = "fam-invest";

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

async function wipe() {
  for (const sub of ["ledger", "investmentRequests", "members"]) {
    const docs = await db.collection(`families/${FAMILY}/${sub}`).get();
    await Promise.all(docs.docs.map((d) => d.ref.delete()));
  }
  const lots = await db
    .collection(`families/${FAMILY}/investments/m1/lots`)
    .get();
  await Promise.all(lots.docs.map((d) => d.ref.delete()));
  await db.doc(`families/${FAMILY}`).set({
    name: "Silva",
    guardianUids: ["g1"],
    childUids: ["uid-bia"],
    investmentWeeklyRatePct: 2,
    investmentGraceDays: 7,
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

async function seedLot(points, ageDays) {
  await db.collection(`families/${FAMILY}/investments/m1/lots`).add({
    points,
    memberUid: "uid-bia",
    createdAt: Timestamp.fromMillis(Date.now() - ageDays * 24 * 3600 * 1000),
  });
}

async function balance(memberId) {
  const snap = await db
    .collection(`families/${FAMILY}/ledger`)
    .where("memberId", "==", memberId)
    .get();
  return snap.docs.reduce((s, d) => s + d.data().points, 0);
}

const dep = (points) => ({
  familyId: FAMILY,
  memberId: "m1",
  memberUid: "uid-bia",
  kind: "deposit",
  points,
  requestedByUid: "uid-bia",
});

beforeEach(wipe);

test("requestInvestment(deposit) recusa saldo insuficiente e pontos <= 0", async () => {
  await seedBalance("m1", 50);
  await assert.rejects(() => requestInvestment(db, dep(100)), InvestmentError);
  await assert.rejects(() => requestInvestment(db, dep(0)), InvestmentError);
});

test("requestInvestment(withdraw) recusa sem lotes", async () => {
  await assert.rejects(
    () =>
      requestInvestment(db, {
        familyId: FAMILY,
        memberId: "m1",
        memberUid: "uid-bia",
        kind: "withdraw",
        requestedByUid: "uid-bia",
      }),
    (e) => e instanceof InvestmentError && e.code === "failed-precondition",
  );
});

test("approveInvestment(deposit) debita e cria o lote", async () => {
  await seedBalance("m1", 300);
  const { reqId } = await requestInvestment(db, dep(120));

  const result = await approveInvestment(db, {
    familyId: FAMILY,
    reqId,
    deciderUid: "g1",
  });
  assert.equal(result.newBalance, 180);
  assert.equal(await balance("m1"), 180);

  const debit = (
    await db
      .collection(`families/${FAMILY}/ledger`)
      .where("sourceType", "==", "investment")
      .get()
  ).docs[0].data();
  assert.equal(debit.points, -120);
  assert.equal(debit.memberUid, "uid-bia");

  const lots = await db
    .collection(`families/${FAMILY}/investments/m1/lots`)
    .get();
  assert.equal(lots.size, 1);
  assert.equal(lots.docs[0].data().points, 120);

  const req = await db
    .doc(`families/${FAMILY}/investmentRequests/${reqId}`)
    .get();
  assert.equal(req.data().status, "approved");
});

test("approveInvestment(withdraw) soma lotes com rendimento e apaga", async () => {
  await seedLot(1000, 70); // fora da carência
  const { reqId } = await requestInvestment(db, {
    familyId: FAMILY,
    memberId: "m1",
    memberUid: "uid-bia",
    kind: "withdraw",
    requestedByUid: "uid-bia",
  });

  const result = await approveInvestment(db, {
    familyId: FAMILY,
    reqId,
    deciderUid: "g1",
  });

  // 1000 * 1.02^10 ≈ 1219 -> rendimento ~219
  const expectedYield = grossYield(1000, 10, 2);
  assert.equal(result.yieldPoints, expectedYield);
  assert.equal(result.payoutPoints, 1000 + expectedYield);
  assert.equal(await balance("m1"), 1000 + expectedYield);

  const lots = await db
    .collection(`families/${FAMILY}/investments/m1/lots`)
    .get();
  assert.equal(lots.size, 0);

  const credit = (
    await db
      .collection(`families/${FAMILY}/ledger`)
      .where("type", "==", "earn")
      .get()
  ).docs[0].data();
  assert.equal(credit.sourceType, "investment");
});

test("approveInvestment(withdraw): lote na carência rende metade", async () => {
  await seedLot(2000, 3); // < 7 dias
  const { reqId } = await requestInvestment(db, {
    familyId: FAMILY,
    memberId: "m1",
    memberUid: "uid-bia",
    kind: "withdraw",
    requestedByUid: "uid-bia",
  });
  const result = await approveInvestment(db, {
    familyId: FAMILY,
    reqId,
    deciderUid: "g1",
  });
  const full = grossYield(2000, 3 / 7, 2);
  assert.equal(result.yieldPoints, Math.round(full * 0.5));
});

test("approveInvestment não aprova duas vezes", async () => {
  await seedBalance("m1", 500);
  const { reqId } = await requestInvestment(db, dep(100));
  await approveInvestment(db, { familyId: FAMILY, reqId, deciderUid: "g1" });
  await assert.rejects(
    () => approveInvestment(db, { familyId: FAMILY, reqId, deciderUid: "g1" }),
    (e) => e instanceof InvestmentError && e.code === "failed-precondition",
  );
  assert.equal(await balance("m1"), 400);
});
