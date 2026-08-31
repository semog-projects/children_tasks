// Convite e vínculo de criança / responsável (issue #33). Requer o emulador
// do Firestore.
//   firebase emulators:exec --only firestore "npm --prefix functions run test:integration"

import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import {
  acceptInvite,
  createInvite,
  InviteError,
  listOpenInvites,
  revokeInvite,
} from "../lib/family/invites.js";

process.env.GCLOUD_PROJECT ??= "demo-children-tasks";

let db;
let familyId;
let biaId;

before(() => {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  db = getFirestore();
});
after(async () => db.terminate());

async function wipe() {
  for (const col of ["families", "familyInvites", "users"]) {
    const snap = await db.collection(col).get();
    for (const doc of snap.docs) {
      if (col === "families") {
        for (const sub of ["members", "taskInstances", "ledger"]) {
          const sd = await doc.ref.collection(sub).get();
          await Promise.all(sd.docs.map((d) => d.ref.delete()));
        }
      }
      await doc.ref.delete();
    }
  }
}

beforeEach(async () => {
  await wipe();
  const family = await db.collection("families").add({
    name: "Silva",
    guardianUids: ["g1"],
    guardians: [{ uid: "g1", displayName: "Ana" }],
    timezone: "America/Sao_Paulo",
  });
  familyId = family.id;
  const bia = await family.collection("members").add({
    type: "child",
    displayName: "Bia",
  });
  biaId = bia.id;
});

test("responsável cria convite de criança; o doc tem os campos certos", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });

  assert.match(code, /^[A-Z0-9]{8}$/);
  const invite = (await db.doc(`familyInvites/${code}`).get()).data();
  assert.equal(invite.familyId, familyId);
  assert.equal(invite.role, "child");
  assert.equal(invite.memberId, biaId);
  assert.equal(invite.acceptedByUid, null);
});

test("não-responsável não cria convite", async () => {
  await assert.rejects(
    () =>
      createInvite(db, {
        familyId,
        createdByUid: "estranho",
        role: "child",
        memberId: biaId,
      }),
    (e) => e instanceof InviteError && e.code === "permission-denied",
  );
});

test("aceitar convite de criança vincula a conta e cria o perfil", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });

  const result = await acceptInvite(db, {
    code,
    uid: "uid-bia",
    displayName: "Bia S.",
    email: "Bia@Example.com",
  });
  assert.deepEqual(result, { familyId, role: "child", memberId: biaId });

  const member = (await db.doc(`families/${familyId}/members/${biaId}`).get()).data();
  assert.equal(member.linkedUid, "uid-bia");

  const family = (await db.doc(`families/${familyId}`).get()).data();
  assert.deepEqual(family.childUids, ["uid-bia"]);

  const user = (await db.doc("users/uid-bia").get()).data();
  assert.equal(user.role, "child");
  assert.equal(user.email, "bia@example.com");
  assert.ok(user.createdAt);

  const invite = (await db.doc(`familyInvites/${code}`).get()).data();
  assert.equal(invite.acceptedByUid, "uid-bia");
});

test("aceitar faz backfill de memberUid em taskInstances e ledger", async () => {
  await db.doc(`families/${familyId}/taskInstances/i1`).set({
    taskId: "t1",
    memberId: biaId,
    status: "pending",
  });
  await db.doc(`families/${familyId}/ledger/earn__i0`).set({
    memberId: biaId,
    type: "earn",
    points: 5,
  });
  // de outra criança — não deve ser tocado
  await db.doc(`families/${familyId}/taskInstances/i2`).set({
    taskId: "t1",
    memberId: "outro",
    status: "pending",
  });

  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });
  await acceptInvite(db, { code, uid: "uid-bia" });

  const i1 = (await db.doc(`families/${familyId}/taskInstances/i1`).get()).data();
  assert.equal(i1.memberUid, "uid-bia");
  const l0 = (await db.doc(`families/${familyId}/ledger/earn__i0`).get()).data();
  assert.equal(l0.memberUid, "uid-bia");
  const i2 = (await db.doc(`families/${familyId}/taskInstances/i2`).get()).data();
  assert.equal(i2.memberUid, undefined);
});

test("aceitar é idempotente para o mesmo uid", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });
  await acceptInvite(db, { code, uid: "uid-bia" });
  await acceptInvite(db, { code, uid: "uid-bia" });

  const family = (await db.doc(`families/${familyId}`).get()).data();
  assert.deepEqual(family.childUids, ["uid-bia"]);
});

test("outro uid não reaproveita um convite já aceito", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });
  await acceptInvite(db, { code, uid: "uid-bia" });

  await assert.rejects(
    () => acceptInvite(db, { code, uid: "intruso" }),
    (e) => e instanceof InviteError && e.code === "failed-precondition",
  );
});

test("convite expirado é recusado", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
    now: new Date("2026-01-01T00:00:00Z"),
    ttlDays: 1,
  });

  await assert.rejects(
    () =>
      acceptInvite(db, {
        code,
        uid: "uid-bia",
        now: new Date("2026-01-05T00:00:00Z"),
      }),
    (e) => e instanceof InviteError && e.code === "failed-precondition",
  );
});

test("não cria convite para criança já vinculada", async () => {
  await db
    .doc(`families/${familyId}/members/${biaId}`)
    .set({ linkedUid: "uid-bia" }, { merge: true });

  await assert.rejects(
    () =>
      createInvite(db, {
        familyId,
        createdByUid: "g1",
        role: "child",
        memberId: biaId,
      }),
    (e) => e instanceof InviteError && e.code === "already-exists",
  );
});

test("convite de responsável por e-mail: só o e-mail certo aceita", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "guardian",
    email: "papai@example.com",
  });

  await assert.rejects(
    () => acceptInvite(db, { code, uid: "uid-x", email: "outro@example.com" }),
    (e) => e instanceof InviteError && e.code === "permission-denied",
  );

  await acceptInvite(db, {
    code,
    uid: "uid-papai",
    displayName: "Papai",
    email: "papai@example.com",
  });
  const family = (await db.doc(`families/${familyId}`).get()).data();
  assert.ok(family.guardianUids.includes("uid-papai"));
  assert.ok(family.guardians.some((g) => g.uid === "uid-papai"));
});

test("código inexistente é not-found", async () => {
  await assert.rejects(
    () => acceptInvite(db, { code: "ZZZZZZZZ", uid: "x" }),
    (e) => e instanceof InviteError && e.code === "not-found",
  );
});

test("listOpenInvites: só os abertos, e só para responsável", async () => {
  const { code: c1 } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "guardian",
    email: "papai@example.com",
  });
  const { code: c2 } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });
  await acceptInvite(db, { code: c2, uid: "uid-bia" });

  const open = await listOpenInvites(db, familyId, "g1");
  assert.deepEqual(
    open.map((i) => i.code),
    [c1],
  );
  assert.equal(open[0].email, "papai@example.com");

  await assert.rejects(
    () => listOpenInvites(db, familyId, "estranho"),
    (e) => e instanceof InviteError && e.code === "permission-denied",
  );
});

test("listOpenInvites: esconde os expirados", async () => {
  await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "guardian",
    email: "velho@example.com",
    now: new Date("2026-01-01T00:00:00Z"),
    ttlDays: 1,
  });
  const open = await listOpenInvites(db, familyId, "g1", new Date("2026-02-01T00:00:00Z"));
  assert.equal(open.length, 0);
});

test("revokeInvite: responsável apaga; idempotente; não apaga aceito", async () => {
  const { code } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "guardian",
    email: "x@example.com",
  });
  await revokeInvite(db, code, "g1");
  assert.equal((await db.doc(`familyInvites/${code}`).get()).exists, false);
  await revokeInvite(db, code, "g1"); // idempotente

  const { code: accepted } = await createInvite(db, {
    familyId,
    createdByUid: "g1",
    role: "child",
    memberId: biaId,
  });
  await acceptInvite(db, { code: accepted, uid: "uid-bia" });
  await assert.rejects(
    () => revokeInvite(db, accepted, "g1"),
    (e) => e instanceof InviteError && e.code === "failed-precondition",
  );
});
