import { randomInt } from "node:crypto";

import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";

/** Erro de regra de negócio no convite. `code` vira o code do HttpsError. */
export class InviteError extends Error {
  constructor(
    readonly code:
      | "not-found"
      | "failed-precondition"
      | "permission-denied"
      | "already-exists"
      | "invalid-argument",
    message: string,
  ) {
    super(message);
  }
}

const INVITE_TTL_DAYS = 7;
// Sem caracteres ambíguos (0/O, 1/I/L).
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;

function newCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i += 1) {
    code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

function normalizeEmail(email: string | null | undefined): string | null {
  const clean = email?.trim().toLowerCase();
  return clean && clean.length > 0 ? clean : null;
}

async function assertInviteGuardian(
  db: Firestore,
  familyId: string,
  uid: string,
): Promise<void> {
  const snap = await db.doc(`families/${familyId}`).get();
  const guardianUids = (snap.data()?.guardianUids ?? []) as string[];
  if (!snap.exists || !guardianUids.includes(uid)) {
    throw new InviteError(
      "permission-denied",
      "Você não é responsável desta família.",
    );
  }
}

export interface CreateInviteParams {
  familyId: string;
  createdByUid: string;
  role: "child" | "guardian";
  /** Obrigatório quando `role === "child"`. */
  memberId?: string;
  /** Opcional; quando presente, o aceite exige que o e-mail bata. */
  email?: string | null;
  now?: Date;
  ttlDays?: number;
}

export interface CreateInviteResult {
  code: string;
  expiresAt: Date;
}

/**
 * Cria um convite para entrar numa família — como criança (vínculo de um
 * `member`) ou como responsável. Só um responsável da família pode criar.
 */
export async function createInvite(
  db: Firestore,
  params: CreateInviteParams,
): Promise<CreateInviteResult> {
  await assertInviteGuardian(db, params.familyId, params.createdByUid);

  if (params.role === "child") {
    if (!params.memberId) {
      throw new InviteError("invalid-argument", "memberId é obrigatório.");
    }
    const memberSnap = await db
      .doc(`families/${params.familyId}/members/${params.memberId}`)
      .get();
    if (!memberSnap.exists || memberSnap.data()?.type !== "child") {
      throw new InviteError("not-found", "Criança não encontrada.");
    }
    if (memberSnap.data()?.linkedUid) {
      throw new InviteError(
        "already-exists",
        "Esta criança já tem uma conta vinculada.",
      );
    }
  }

  const now = params.now ?? new Date();
  const ttlDays = params.ttlDays ?? INVITE_TTL_DAYS;
  const expiresAt = new Date(now.getTime() + ttlDays * 24 * 60 * 60 * 1000);

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = newCode();
    try {
      await db.doc(`familyInvites/${code}`).create({
        familyId: params.familyId,
        role: params.role,
        memberId: params.memberId ?? null,
        email: normalizeEmail(params.email),
        createdByUid: params.createdByUid,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromDate(expiresAt),
        acceptedByUid: null,
        acceptedAt: null,
      });
      return { code, expiresAt };
    } catch (error) {
      const e = error as { code?: number | string };
      if (e.code === 6 || e.code === "already-exists") continue; // colisão rara
      throw error;
    }
  }
  throw new InviteError("failed-precondition", "Não foi possível gerar um código. Tente de novo.");
}

export interface OpenInvite {
  code: string;
  role: "child" | "guardian";
  email: string | null;
  memberId: string | null;
  expiresAt: Date;
}

/** Convites em aberto (não aceitos, não expirados) de uma família. */
export async function listOpenInvites(
  db: Firestore,
  familyId: string,
  callerUid: string,
  now: Date = new Date(),
): Promise<OpenInvite[]> {
  await assertInviteGuardian(db, familyId, callerUid);
  const snap = await db
    .collection("familyInvites")
    .where("familyId", "==", familyId)
    .where("acceptedByUid", "==", null)
    .get();
  return snap.docs
    .map((d) => {
      const data = d.data();
      return {
        code: d.id,
        role: data.role as "child" | "guardian",
        email: (data.email as string | null) ?? null,
        memberId: (data.memberId as string | null) ?? null,
        expiresAt: (data.expiresAt as Timestamp).toDate(),
      };
    })
    .filter((i) => i.expiresAt.getTime() > now.getTime());
}

/** Revoga (apaga) um convite ainda não aceito. Idempotente. */
export async function revokeInvite(
  db: Firestore,
  code: string,
  callerUid: string,
): Promise<void> {
  const ref = db.doc(`familyInvites/${code.trim().toUpperCase()}`);
  const snap = await ref.get();
  if (!snap.exists) return;
  await assertInviteGuardian(db, snap.data()!.familyId as string, callerUid);
  if (snap.data()!.acceptedByUid) {
    throw new InviteError("failed-precondition", "Convite já utilizado.");
  }
  await ref.delete();
}

export interface AcceptInviteParams {
  code: string;
  uid: string;
  displayName?: string | null;
  email?: string | null;
  photoUrl?: string | null;
  now?: Date;
}

export interface AcceptInviteResult {
  familyId: string;
  role: "child" | "guardian";
  memberId: string | null;
}

/**
 * Aceita um convite. Numa transação, "reserva" o convite (valida validade e
 * uso único, grava `acceptedByUid`); fora da transação aplica o vínculo
 * (idempotente) — atualiza `member`/`family`, cria `users/{uid}` e faz o
 * backfill de `memberUid`.
 */
export async function acceptInvite(
  db: Firestore,
  params: AcceptInviteParams,
): Promise<AcceptInviteResult> {
  const code = params.code.trim().toUpperCase();
  const inviteRef = db.doc(`familyInvites/${code}`);
  const now = params.now ?? new Date();
  const email = normalizeEmail(params.email);

  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(inviteRef);
    if (!snap.exists) {
      throw new InviteError("not-found", "Convite não encontrado.");
    }
    const invite = snap.data()!;
    const familyId = invite.familyId as string;
    const role = invite.role as "child" | "guardian";
    const memberId = (invite.memberId as string | null) ?? null;

    const expiresAt = (invite.expiresAt as Timestamp | undefined)?.toDate();
    if (expiresAt && expiresAt.getTime() < now.getTime()) {
      throw new InviteError("failed-precondition", "Convite expirado.");
    }
    const acceptedBy = invite.acceptedByUid as string | null | undefined;
    if (acceptedBy && acceptedBy !== params.uid) {
      throw new InviteError("failed-precondition", "Convite já utilizado.");
    }
    if (role === "guardian" && invite.email && email !== invite.email) {
      throw new InviteError(
        "permission-denied",
        "Este convite é para outro e-mail.",
      );
    }
    if (role === "child") {
      if (!memberId) {
        throw new InviteError("failed-precondition", "Convite inválido.");
      }
      const memberSnap = await tx.get(
        db.doc(`families/${familyId}/members/${memberId}`),
      );
      const linkedUid = memberSnap.data()?.linkedUid as string | undefined;
      if (!memberSnap.exists) {
        throw new InviteError("not-found", "Criança não encontrada.");
      }
      if (linkedUid && linkedUid !== params.uid) {
        throw new InviteError(
          "failed-precondition",
          "Esta criança já está vinculada a outra conta.",
        );
      }
    }

    if (!acceptedBy) {
      tx.update(inviteRef, {
        acceptedByUid: params.uid,
        acceptedAt: FieldValue.serverTimestamp(),
      });
    }
    return { familyId, role, memberId };
  });

  if (claimed.role === "child") {
    await linkChild(db, claimed.familyId, claimed.memberId!, params);
  } else {
    await addGuardian(db, claimed.familyId, params);
  }
  return claimed;
}

async function upsertUser(
  db: Firestore,
  uid: string,
  data: Record<string, unknown>,
): Promise<void> {
  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  await ref.set(
    {
      ...data,
      lastLoginAt: FieldValue.serverTimestamp(),
      ...(snap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
    },
    { merge: true },
  );
}

async function linkChild(
  db: Firestore,
  familyId: string,
  memberId: string,
  params: AcceptInviteParams,
): Promise<void> {
  await db.doc(`families/${familyId}/members/${memberId}`).set(
    { linkedUid: params.uid, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  await db.doc(`families/${familyId}`).set(
    {
      childUids: FieldValue.arrayUnion(params.uid),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await upsertUser(db, params.uid, {
    displayName: params.displayName ?? null,
    email: normalizeEmail(params.email),
    photoUrl: params.photoUrl ?? null,
    role: "child",
  });
  await backfillMemberUid(db, familyId, memberId, params.uid);
}

async function addGuardian(
  db: Firestore,
  familyId: string,
  params: AcceptInviteParams,
): Promise<void> {
  const familyRef = db.doc(`families/${familyId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(familyRef);
    const guardianUids = (snap.data()?.guardianUids ?? []) as string[];
    const guardians = (snap.data()?.guardians ?? []) as Array<
      Record<string, unknown>
    >;
    const entry: Record<string, unknown> = {
      uid: params.uid,
      displayName: params.displayName?.trim() || "Responsável",
    };
    if (params.photoUrl) entry.photoUrl = params.photoUrl;

    tx.update(familyRef, {
      guardianUids: guardianUids.includes(params.uid)
        ? guardianUids
        : [...guardianUids, params.uid],
      guardians: [
        ...guardians.filter((g) => g.uid !== params.uid),
        entry,
      ],
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  await upsertUser(db, params.uid, {
    displayName: params.displayName ?? null,
    email: normalizeEmail(params.email),
    photoUrl: params.photoUrl ?? null,
  });
}

/**
 * Copia o `uid` da criança para o campo `memberUid` das `taskInstances` e
 * entradas de `ledger` já existentes daquele `memberId` — usado pelas rules
 * da criança (issue #34). Idempotente.
 */
async function backfillMemberUid(
  db: Firestore,
  familyId: string,
  memberId: string,
  uid: string,
): Promise<void> {
  for (const sub of ["taskInstances", "ledger"]) {
    const snap = await db
      .collection(`families/${familyId}/${sub}`)
      .where("memberId", "==", memberId)
      .get();
    const stale = snap.docs.filter((d) => d.data().memberUid !== uid);
    for (let i = 0; i < stale.length; i += 400) {
      const batch = db.batch();
      for (const doc of stale.slice(i, i + 400)) {
        batch.update(doc.ref, { memberUid: uid });
      }
      await batch.commit();
    }
  }
}
