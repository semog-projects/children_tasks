// Guard de funcionalidades ligadas/desligadas por família (issue #75).
// Requer o emulador.

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import {
  assertFeatureEnabled,
  FeatureDisabledError,
} from "../lib/family/features.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
const FAMILY = "fam-features";

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

beforeEach(async () => {
  await db.doc(`families/${FAMILY}`).set({ name: "Silva", guardianUids: ["g1"] });
});

test("passa quando a feature não está desligada", async () => {
  await assert.doesNotReject(() =>
    assertFeatureEnabled(db, FAMILY, "investment"),
  );
});

test("passa quando disabledFeatures não existe", async () => {
  await db.doc(`families/${FAMILY}`).set({ name: "Silva", guardianUids: ["g1"] });
  await assert.doesNotReject(() => assertFeatureEnabled(db, FAMILY, "rewards"));
});

test("lança FeatureDisabledError (failed-precondition) quando desligada", async () => {
  await db
    .doc(`families/${FAMILY}`)
    .set({ disabledFeatures: ["cashOut", "investment"] }, { merge: true });

  await assert.rejects(
    () => assertFeatureEnabled(db, FAMILY, "cashOut"),
    (e) => e instanceof FeatureDisabledError && e.code === "failed-precondition",
  );
  await assert.rejects(
    () => assertFeatureEnabled(db, FAMILY, "investment"),
    FeatureDisabledError,
  );
  // outra feature segue liberada
  await assert.doesNotReject(() =>
    assertFeatureEnabled(db, FAMILY, "rewards"),
  );
});
