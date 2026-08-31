# Modelo de dados — Firestore

Definido na issue #6. Base para tarefas, aprovação, pontos e recompensas.

## Decisão: só o responsável autentica

Crianças **não têm conta** própria (por ora). O app tem "modo criança" como
troca de perfil local dentro da sessão do responsável (issue #8), protegida
por PIN. Consequência:

- Todo acesso ao Firestore acontece sob o `auth.uid` de um **responsável**.
- As Security Rules distinguem apenas "é responsável desta família" vs. "não é".
- As restrições do modo criança (não editar tarefas, não se autoaprovar) são
  aplicadas **no cliente**. O campo `members.linkedUid` já existe para, no
  futuro, permitir login de criança e regras mais finas sem migração.

## Coleções

Tudo abaixo de `families/{familyId}`, exceto `users/`.

### `users/{uid}` (raiz)

Perfil do responsável autenticado. Criado no login (issue #5).

| campo | tipo | notas |
|---|---|---|
| `displayName` | string? | do Google |
| `email` | string? | do Google |
| `photoUrl` | string? | do Google |
| `createdAt` | timestamp | server, só na criação |
| `lastLoginAt` | timestamp | server, todo login |

### `families/{familyId}`

| campo | tipo | notas |
|---|---|---|
| `name` | string | 1–60 chars |
| `guardianUids` | list\<string> | uids dos responsáveis; ≥ 1 — **fonte de verdade das rules** |
| `guardians` | list\<map> | `{ uid, displayName, photoUrl? }` — exibição (o `users/{uid}` só é legível pelo dono). Auto-heal quando cada responsável abre o app |
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
| `linkedUid` | string? | responsável: seu uid; criança: reservado p/ futuro |
| `pinHash` | string? | só `guardian`; definido na issue #8 |
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
- Qualquer outro caminho: negado.
