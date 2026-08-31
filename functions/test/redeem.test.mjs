// Resgate transacional de recompensa (issue #12). Requer o emulador.

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

import {
  redeemReward,
  RedeemError,
  resolveRedeemTarget,
} from "../lib/rewards/redeem.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
const FAMILY = "fam1";

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

async function wipe() {
  for (const sub of ["rewards", "ledger", "redemptions", "members"]) {
    const docs = await db.collection(`families/${FAMILY}/${sub}`).get();
    await Promise.all(docs.docs.map((d) => d.ref.delete()));
  }
  await db.doc(`families/${FAMILY}`).set({
    name: "Silva",
    guardianUids: ["g1"],
    childUids: ["uid-bia"],
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

async function seedReward(overrides = {}) {
  const ref = await db.collection(`families/${FAMILY}/rewards`).add({
    title: "Sorvete",
    cost: 50,
    active: true,
    stock: null,
    ...overrides,
  });
  return ref.id;
}

async function balance(memberId) {
  const snap = await db
    .collection(`families/${FAMILY}/ledger`)
    .where("memberId", "==", memberId)
    .get();
  return snap.docs.reduce((s, d) => s + d.data().points, 0);
}

beforeEach(wipe);

const params = (rewardId) => ({
  familyId: FAMILY,
  rewardId,
  memberId: "m1",
  requestedByUid: "g1",
});

test("resgate com saldo suficiente debita e cria o registro", async () => {
  await seedBalance("m1", 100);
  const rewardId = await seedReward();

  const result = await redeemReward(db, params(rewardId));
  assert.equal(result.cost, 50);
  assert.equal(result.newBalance, 50);
  assert.equal(await balance("m1"), 50);

  const redemptions = await db.collection(`families/${FAMILY}/redemptions`).get();
  assert.equal(redemptions.size, 1);
  assert.equal(redemptions.docs[0].data().status, "requested");
  assert.equal(redemptions.docs[0].data().cost, 50);

  const ledger = await db
    .collection(`families/${FAMILY}/ledger`)
    .where("type", "==", "redeem")
    .get();
  assert.equal(ledger.docs[0].data().points, -50);
});

test("saldo insuficiente é bloqueado e nada muda", async () => {
  await seedBalance("m1", 30);
  const rewardId = await seedReward();

  await assert.rejects(() => redeemReward(db, params(rewardId)), RedeemError);
  assert.equal(await balance("m1"), 30);
  assert.equal((await db.collection(`families/${FAMILY}/redemptions`).get()).size, 0);
});

test("sem estoque é bloqueado", async () => {
  await seedBalance("m1", 100);
  const rewardId = await seedReward({ stock: 0 });
  await assert.rejects(() => redeemReward(db, params(rewardId)), RedeemError);
});

test("estoque limitado é decrementado", async () => {
  await seedBalance("m1", 200);
  const rewardId = await seedReward({ stock: 2 });

  await redeemReward(db, params(rewardId));
  const reward = await db.doc(`families/${FAMILY}/rewards/${rewardId}`).get();
  assert.equal(reward.data().stock, 1);
});

test("recompensa inativa é bloqueada", async () => {
  await seedBalance("m1", 100);
  const rewardId = await seedReward({ active: false });
  await assert.rejects(() => redeemReward(db, params(rewardId)), RedeemError);
});

test("dois resgates seguidos: o segundo respeita o saldo já debitado", async () => {
  await seedBalance("m1", 60);
  const rewardId = await seedReward();

  await redeemReward(db, params(rewardId)); // saldo 10
  await assert.rejects(() => redeemReward(db, params(rewardId)), RedeemError);
  assert.equal(await balance("m1"), 10);
});

test("grava memberUid no resgate e no débito quando passado", async () => {
  await seedBalance("m1", 100);
  const rewardId = await seedReward();
  await redeemReward(db, { ...params(rewardId), memberUid: "uid-bia" });

  const redemption = (
    await db.collection(`families/${FAMILY}/redemptions`).get()
  ).docs[0].data();
  assert.equal(redemption.memberUid, "uid-bia");
  const debit = (
    await db
      .collection(`families/${FAMILY}/ledger`)
      .where("type", "==", "redeem")
      .get()
  ).docs[0].data();
  assert.equal(debit.memberUid, "uid-bia");
});

test("resolveRedeemTarget: responsável resgata para qualquer criança", async () => {
  const target = await resolveRedeemTarget(db, FAMILY, "g1", "m1");
  assert.deepEqual(target, { memberId: "m1", memberUid: "uid-bia" });
});

test("resolveRedeemTarget: criança resgata só para si (ignora memberId pedido)", async () => {
  await db.doc(`families/${FAMILY}/members/m2`).set({
    type: "child",
    displayName: "Léo",
  });
  const target = await resolveRedeemTarget(db, FAMILY, "uid-bia", "m2");
  assert.deepEqual(target, { memberId: "m1", memberUid: "uid-bia" });
});

test("resolveRedeemTarget: quem não é da família é barrado", async () => {
  await assert.rejects(
    () => resolveRedeemTarget(db, FAMILY, "estranho", "m1"),
    (e) => e instanceof RedeemError && e.code === "permission-denied",
  );
});

test("resolveRedeemTarget: uid em childUids mas sem member vinculado é barrado", async () => {
  await db.doc(`families/${FAMILY}`).set(
    { childUids: ["uid-bia", "uid-orfao"] },
    { merge: true },
  );
  await assert.rejects(
    () => resolveRedeemTarget(db, FAMILY, "uid-orfao", undefined),
    (e) => e instanceof RedeemError && e.code === "permission-denied",
  );
});
