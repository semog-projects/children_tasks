# Modelo de dados — Firestore

Definido na issue #6. Base para tarefas, aprovação, pontos e recompensas.

## Autenticação: responsável e criança

> **Revisão (Sprint 2, issues #32–#35):** a decisão original "só o responsável
> autentica" está sendo revertida. Cada criança passa a ter **login próprio
> (conta Google)** e usa o próprio aparelho — sai o "modo criança" local por
> PIN da issue #8. A entrega é incremental:
> - **#32 (feito):** o app resolve o *papel* pós-login (responsável / criança /
>   sem família) e monta a navegação. Campo `families.childUids` adicionado.
> - **#33:** convite e vínculo `auth.uid` ↔ `members/{id}` (`linkedUid` +
>   `childUids`), Cloud Functions gravam `memberUid` em `taskInstances`/`ledger`.
> - **#34:** Security Rules ganham o papel "criança" e a trava de
>   auto-aprovação passa do cliente para o servidor.
> - **#35:** ações da criança (marcar tarefa, pedir resgate) e notificações.

Até a #34, as rules ainda distinguem apenas "é responsável desta família" vs.
"não é", e as restrições do modo criança são aplicadas **no cliente**.

## Coleções

Tudo abaixo de `families/{familyId}`, exceto `users/`.

### `users/{uid}` (raiz)

Perfil de quem autentica — responsável (login, issue #5) ou criança (ao
aceitar o convite, issue #33).

| campo | tipo | notas |
|---|---|---|
| `displayName` | string? | do Google |
| `email` | string? | do Google (minúsculas) |
| `photoUrl` | string? | do Google |
| `role` | string? | `child` quando o doc foi criado pelo vínculo de criança (#33); ausente para responsável |
| `createdAt` | timestamp | server, só na criação |
| `lastLoginAt` | timestamp | server, todo login |
| `pinHash` / `pinSalt` | string? | Reservado para um app-lock opcional. Era o cadeado do "modo criança → modo responsável" (issue #8), removido na #32 junto com o modo criança local |
| `notif` | map | preferências de notificação (issue #14): `pendingApproval`, `approvalResult`, `redemption`, `dailyReminder` (bool, default true), `reminderHour` (int 0–23, default 18), `lastReminderDate` (`YYYY-MM-DD`, dedup do lembrete) |

Subcoleção `users/{uid}/fcmTokens/{token}` — um doc por dispositivo (id = o
token FCM), campos `platform` e `updatedAt`. Só o dono lê/escreve; as
Functions leem via admin. Tokens inválidos são apagados pela Function ao
falhar o envio.

### `familyInvites/{code}` (raiz)

Convite para entrar numa família (issue #33). `code` = id do doc (8 chars,
alfabeto sem ambíguos). **Só as Functions leem/escrevem** — o cliente age
pelas callables `createFamilyInvite` / `acceptFamilyInvite`.

| campo | tipo | notas |
|---|---|---|
| `familyId` | string | família alvo |
| `role` | string | `child` \| `guardian` |
| `memberId` | string? | obrigatório p/ `child`: o `member` a vincular |
| `email` | string? | quando presente, o aceite exige `auth.token.email` igual |
| `createdByUid` | string | responsável que gerou |
| `createdAt` | timestamp | server |
| `expiresAt` | timestamp | TTL 7 dias |
| `acceptedByUid` / `acceptedAt` | string? / timestamp? | uso único (idempotente p/ o mesmo uid) |

`acceptFamilyInvite`: numa transação reserva o convite (validade + uso único);
fora dela aplica o vínculo — `role: child` → `members/{id}.linkedUid`,
`family.childUids` (arrayUnion), `users/{uid}` (`role: child`), backfill de
`memberUid`; `role: guardian` → `family.guardianUids` + `guardians`.

### `families/{familyId}`

| campo | tipo | notas |
|---|---|---|
| `name` | string | 1–60 chars |
| `guardianUids` | list\<string> | uids dos responsáveis; ≥ 1 — **fonte de verdade das rules** |
| `guardians` | list\<map> | `{ uid, displayName, photoUrl? }` — exibição (o `users/{uid}` só é legível pelo dono). Auto-heal quando cada responsável abre o app |
| `childUids` | list\<string> | uids das crianças com login próprio vinculado (issue #33). Espelho de `members/{id}.linkedUid` para `type == 'child'`; gerido pelas Functions. **Fonte de verdade das rules** para o papel "criança" (#34) |
| `timezone` | string | IANA (ex.: `America/Sao_Paulo`); usado na geração de recorrentes |
| `createdAt` / `updatedAt` | timestamp | server |

### `families/{familyId}/members/{memberId}`

> **Só crianças.** Responsáveis vivem em `family.guardianUids` +
> `family.guardians` + `users/{uid}` — o app não cria member docs de
> `guardian` (o schema permite, mas não é usado hoje).

| campo | tipo | notas |
|---|---|---|
| `type` | string | `guardian` \| `child` |
| `displayName` | string | 1–60 chars |
| `avatarColor` | string? | hex `#RRGGBB` |
| `photoUrl` | string? | responsáveis: foto do Google |
| `linkedUid` | string? | responsável: seu uid; criança: uid da conta Google vinculada por convite (issue #33) — espelhado em `family.childUids` |
| `pinHash` | string? | legado da issue #8 (modo responsável); não usado desde a #32 |
| `birthDate` | timestamp? | criança (opcional) |
| `createdAt` / `updatedAt` | timestamp | server |

### `families/{familyId}/tasks/{taskId}`

Modelo/definição da tarefa. As ocorrências ficam em `taskInstances`.

| campo | tipo | notas |
|---|---|---|
| `title` | string | 1–80 chars |
| `description` | string? | ≤ 500 chars |
| `points` | int | > 0 |
| `category` | string | `routine` \| `study` \| `chores` \| `hygiene` \| `other` |
| `assigneeMemberId` | string? | `null` = todas as crianças |
| `recurrence` | map | ver abaixo |
| `requiresApproval` | bool | default `true` |
| `active` | bool | `false` = arquivada |
| `createdAt` / `updatedAt` | timestamp | server |

`recurrence`:
```jsonc
{
  "type": "once" | "daily" | "weekly",
  "daysOfWeek": [1, 3, 5],   // 1=seg, 7=dom; usado quando type=weekly
  "startDate": <timestamp>,   // dia de início (inclusive)
  "endDate": <timestamp|null> // dia de fim (inclusive) ou null = sem fim
}
```

### `families/{familyId}/taskInstances/{instanceId}`

Uma ocorrência de uma tarefa para uma criança num dia. Criadas pela Cloud
Function `generateDailyInstances` (agendada, de hora em hora) e pela callable
`generateInstances` (o app chama ao abrir) — issue #10.

**ID determinístico:** `{taskId}__{memberId}__{YYYY-MM-DD}` — garante
idempotência (rodar a geração de novo não duplica).

**`date`:** a data é o **calendário local da família**, mas gravada como
`Timestamp` de meia-noite **UTC** desse dia (`YYYY-MM-DDT00:00:00Z`). O app
exibe só a data, então não há ambiguidade. Ver `functions/src/shared/dates.ts`.

| campo | tipo | notas |
|---|---|---|
| `taskId` | string | ref a `tasks` |
| `memberId` | string | a criança |
| `memberUid` | string? | `linkedUid` da criança, quando ela tem login próprio. Gravado pelas Functions (geração + backfill no vínculo, #33); usado pelas rules da criança (#34) |
| `date` | timestamp | meia-noite UTC do dia local (ver acima) |
| `status` | string | `pending` \| `awaitingApproval` \| `approved` \| `rejected` |
| `titleSnapshot` | string | título da tarefa no momento da criação |
| `pointsSnapshot` | int | pontos no momento da criação |
| `requiresApproval` | bool | copiado da tarefa |
| `completedAt` | timestamp? | quando a criança marcou |
| `reviewedByUid` | string? | responsável que aprovou/rejeitou |
| `reviewedAt` | timestamp? | |
| `rejectionReason` | string? | |
| `pointsAwarded` | int? | escrito **só pela Function** ao aprovar (= `pointsSnapshot`) |
| `createdAt` / `updatedAt` | timestamp | server |

Transições de `status` (issue #11):
- criança marca feita: `pending → awaitingApproval` (ou `→ approved` se
  `requiresApproval == false`), grava `completedAt`, limpa `rejectionReason`
- responsável aprova: `awaitingApproval → approved` + `reviewedByUid/reviewedAt`
- responsável rejeita: `awaitingApproval → pending` + `rejectionReason`,
  limpa `completedAt` (a criança pode refazer)

**Crédito de pontos:** a Function `onTaskInstanceWritten` reage à transição
para `approved` e cria `ledger/earn__{instanceId}` (id determinístico →
idempotente, revisão dupla não credita 2×). As rules impedem o cliente de
gravar `pointsAwarded` ou pular direto para `approved` quando a tarefa exige
aprovação.

### `families/{familyId}/rewards/{rewardId}`

| campo | tipo | notas |
|---|---|---|
| `title` | string | 1–80 chars |
| `description` | string? | ≤ 500 chars |
| `cost` | int | > 0 |
| `active` | bool | |
| `stock` | int? | `null` = ilimitado; senão ≥ 0 |
| `createdAt` / `updatedAt` | timestamp | server |

### `families/{familyId}/redemptions/{redemptionId}`

Um resgate de recompensa. Criado **só pela Function `redeemReward`** (débito
transacional). O responsável marca como `delivered`.

| campo | tipo | notas |
|---|---|---|
| `rewardId` | string | ref a `rewards` |
| `memberId` | string | a criança |
| `rewardTitleSnapshot` | string | título no momento do resgate |
| `cost` | int | pontos debitados |
| `status` | string | `requested` \| `delivered` \| `canceled` |
| `requestedByUid` | string | responsável |
| `requestedAt` / `deliveredAt` | timestamp | server |
| `deliveredByUid` | string? | quem entregou |

### `families/{familyId}/ledger/{entryId}`

Lançamentos de pontos. **Append-only** (sem update/delete pelo cliente). O
saldo de uma criança é a soma de `points` das entradas dela.

| campo | tipo | notas |
|---|---|---|
| `memberId` | string | a criança |
| `memberUid` | string? | `linkedUid` da criança (quando tem login). Gravado pelas Functions em `earn` + backfill de todas as entradas no vínculo (#33; `redeem` passa a gravar na #35); usado pelas rules da criança (#34) |
| `type` | string | `earn` \| `redeem` \| `adjustment` |
| `points` | int | com sinal: `earn` > 0, `redeem` < 0, `adjustment` qualquer ≠ 0 |
| `sourceType` | string | `taskInstance` \| `reward` \| `manual` |
| `sourceId` | string? | id da instância/resgate |
| `note` | string? | ≤ 200 chars |
| `createdByUid` | string | responsável (ou `system` p/ entradas de Function) |
| `createdAt` | timestamp | server |

**Quem cria o quê:**
- `earn` (id `earn__{instanceId}`) — Function `onTaskInstanceWritten` ao aprovar (#11)
- `redeem` (id `redeem__{redemptionId}`) — Function `redeemReward` (#12)
- `adjustment` — o **cliente** (ajuste manual do responsável)

As rules deixam o cliente criar **só `adjustment`/`manual`**; `earn` e
`redeem` vêm das Functions (admin SDK, ignora rules). Append-only para todos.

## Índices compostos

Ver `firestore.indexes.json`:

- `taskInstances`: `memberId ASC, date ASC` — tarefas do dia de uma criança
- `taskInstances`: `status ASC, date ASC` — fila de aprovação do responsável
- `taskInstances`: `taskId ASC, date ASC` — idempotência da geração de recorrentes
- `ledger`: `memberId ASC, createdAt DESC` — extrato / cálculo de saldo
- `tasks`: `active ASC, category ASC` — listagem filtrada

## Regras de segurança

`firestore.rules`. Resumo:

- `families/{fid}` e todas as subcoleções: acesso total **apenas** para
  `request.auth.uid in family.guardianUids`.
- `create` de `families` exige que o criador esteja em `guardianUids`.
- `ledger`: responsável pode `create` e `read`; `update`/`delete` proibidos.
- Validação de formato em `create`/`update` (enums, ranges, campos obrigatórios).
- `users/{uid}`: cada um só o próprio doc.
- `familyInvites/{code}`: cliente não lê nem escreve (só as Functions).
- Qualquer outro caminho: negado.

## Offline e conflitos (issue #15)

- Cache offline do Firestore ligado (`persistenceEnabled`) — no mobile já vem
  por padrão; no web é explícito.
- **Última escrita vence** para campos simples (comportamento padrão do
  `update()`). Marcar tarefa / aprovar / rejeitar offline funciona: o `status`
  muda localmente e sincroniza depois.
- **Pontos nunca são somados no cliente offline.** O saldo é a soma do
  `ledger`, e as entradas `earn`/`redeem` só existem depois que uma Cloud
  Function roda no servidor (aprovação → `onTaskInstanceWritten`; resgate →
  `redeemReward`, que ainda por cima é uma callable e exige rede). Aprovar
  offline não credita nada até o write sincronizar.
- `SyncBanner` (topo da home e do modo criança) avisa "Sem conexão" ou
  "Sincronizando alterações…" (via `metadata.hasPendingWrites`).
- No catálogo, "Resgatar" fica desabilitado offline.
