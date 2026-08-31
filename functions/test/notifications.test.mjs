// Notificações FCM (issue #14). Requer o emulador do Firestore.

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { notifyGuardians } from "../lib/notifications/messaging.js";
import { sendDueReminders } from "../lib/notifications/reminders.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
const FAMILY = "fam1";

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

/** Sender falso que registra o que foi enviado. */
function fakeSender() {
  const sent = [];
  return {
    sent,
    // por padrão todos os tokens dão certo
    send: async (tokens, notif) => {
      sent.push({ tokens, notif });
      return { successes: tokens.map(() => true) };
    },
  };
}

async function wipe() {
  for (const path of [
    `families/${FAMILY}/taskInstances`,
    `users/g1/fcmTokens`,
    `users/g2/fcmTokens`,
  ]) {
    const docs = await db.collection(path).get();
    await Promise.all(docs.docs.map((d) => d.ref.delete()));
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc(`families/${FAMILY}`).set({
    name: "Silva",
    guardianUids: ["g1", "g2"],
    timezone: "America/Sao_Paulo",
  });
  await db.doc(`users/g1`).set({ notif: {} });
  await db.doc(`users/g2`).set({ notif: {} });
  await db.doc(`users/g1/fcmTokens/tok-g1`).set({ platform: "web" });
  await db.doc(`users/g2/fcmTokens/tok-g2`).set({ platform: "android" });
});

test("notifyGuardians envia para os tokens de todos os responsáveis", async () => {
  const sender = fakeSender();
  const ok = await notifyGuardians(db, FAMILY, "pendingApproval",
    { title: "T", body: "B" }, sender);

  assert.equal(ok, 2);
  assert.deepEqual(sender.sent[0].tokens.sort(), ["tok-g1", "tok-g2"]);
});

test("respeita a preferência desligada", async () => {
  await db.doc(`users/g2`).set({ notif: { pendingApproval: false } });
  const sender = fakeSender();
  await notifyGuardians(db, FAMILY, "pendingApproval", { title: "T", body: "B" }, sender);

  assert.deepEqual(sender.sent[0].tokens, ["tok-g1"]);
});

test("remove tokens inválidos", async () => {
  const sender = {
    sent: [],
    send: async (tokens) => ({ successes: tokens.map((t) => t !== "tok-g2") }),
  };
  await notifyGuardians(db, FAMILY, "pendingApproval", { title: "T", body: "B" }, sender);

  const g2 = await db.collection(`users/g2/fcmTokens`).get();
  assert.equal(g2.size, 0);
  const g1 = await db.collection(`users/g1/fcmTokens`).get();
  assert.equal(g1.size, 1);
});

test("lembrete diário: só na hora certa, uma vez, e só com tarefas pendentes", async () => {
  await db.doc(`users/g1`).set({ notif: { reminderHour: 20 } });
  await db.doc(`users/g2`).set({ notif: { dailyReminder: false } });
  await db.doc(`families/${FAMILY}/taskInstances/i1`).set({
    memberId: "m1",
    status: "pending",
    date: new Date("2026-08-11T00:00:00.000Z"),
  });

  // 2026-08-11 23:00 UTC = 20:00 em São Paulo -> dispara para g1
  const at20 = new Date("2026-08-11T23:00:00Z");
  const sender1 = fakeSender();
  const n1 = await sendDueReminders(db, { now: at20, sender: sender1 });
  assert.equal(n1, 1);
  assert.match(sender1.sent[0].notif.body, /pendente/);

  // rodar de novo no mesmo dia -> nada
  const sender2 = fakeSender();
  const n2 = await sendDueReminders(db, { now: at20, sender: sender2 });
  assert.equal(n2, 0);

  // outra hora -> nada
  await db.doc(`users/g1`).set({ notif: { reminderHour: 20 } }); // limpa lastReminderDate
  const at10 = new Date("2026-08-12T13:00:00Z"); // 10:00 SP
  const sender3 = fakeSender();
  assert.equal(await sendDueReminders(db, { now: at10, sender: sender3 }), 0);
});
