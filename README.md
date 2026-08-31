# children_tasks

[![CI](https://github.com/semog-projects/children_tasks/actions/workflows/ci.yml/badge.svg)](https://github.com/semog-projects/children_tasks/actions/workflows/ci.yml)

Aplicativo em **Flutter** para pais criarem e acompanharem **tarefas diárias
de crianças**, com sistema de pontos e recompensas, integrado ao login Google
e ao conceito de família do Google.

> ⚠️ **Status:** projeto em fase inicial. O scaffold Flutter já existe
> (tema, Riverpod, locale pt-BR); as features do backlog estão sendo
> implementadas uma a uma.

## Visão geral

O objetivo é ajudar famílias a organizar a rotina das crianças de forma lúdica:

- O **responsável** cadastra tarefas (ex.: "arrumar a cama", "ler 15 min",
  "guardar os brinquedos"), define pontos e periodicidade.
- A **criança** vê suas tarefas do dia, marca as concluídas e acumula
  pontos/estrelas.
- Os pontos podem ser trocados por **recompensas** configuradas pelos pais.
- Os pais acompanham o progresso e aprovam conclusões quando necessário.

## Funcionalidades planejadas

- [x] Autenticação com **Google Sign-In** (responsável) — web via popup;
      Android/iOS via `google_sign_in` (precisa de `GOOGLE_SERVER_CLIENT_ID`)
- [ ] Família gerenciada no app, membros associados por conta Google
      (sem sincronizar com o grupo familiar do Google — ver decisão abaixo)
- [ ] App único com **perfis**: modo responsável (protegido por PIN/senha) e
      modo criança
- [ ] Cadastro de crianças/membros da família
- [ ] Criação de tarefas com pontos e categorias
- [ ] **Tarefas recorrentes** (diárias/semanais) geradas automaticamente por agenda
- [ ] Marcação de conclusão pela criança + **aprovação obrigatória do responsável**
      antes de creditar os pontos
- [ ] **Sistema de pontos/recompensas** com catálogo de recompensas resgatáveis
- [ ] Painel de progresso e histórico
- [ ] Sincronização em tempo real entre dispositivos da família
- [ ] Notificações (lembretes de tarefas, tarefa concluída, recompensa resgatada)
- [ ] Suporte offline com sincronização posterior

## Plataformas alvo

- Android
- iOS
- Web (útil para o painel dos pais)
- Desktop (Windows / macOS / Linux)

## Arquitetura

| Camada          | Escolha                                                        |
| --------------- | ------------------------------------------------------------- |
| Frontend        | Flutter (Dart), um único código para todas as plataformas    |
| Autenticação    | Firebase Auth + Google Sign-In                               |
| Banco de dados  | Cloud Firestore (sync em tempo real, suporte offline)        |
| Lógica de back  | Cloud Functions (geração de tarefas recorrentes, regras de pontos) |
| Notificações    | Firebase Cloud Messaging                                     |
| Estado (client) | Riverpod                                                    |
| Idioma          | Português (PT-BR) apenas                                     |

### Integração com o "Google Family"

O escopo pretendido é usar o **Google Sign-In** para autenticar os
responsáveis e associar as crianças a uma família dentro do app.

**Decisão (spike #1, 2026-08-30): integração profunda é inviável hoje.**
A investigação de viabilidade confirmou que:

- **Não existe API pública nem programa de parceria** do Google para apps de
  terceiros lerem ou gravarem grupos familiares (Family Group) ou controles do
  **Family Link** — tarefas, tempo de tela, apps permitidos, aprovações,
  localização. O pedido público por uma API está aberto no issue tracker do
  Google sem previsão (issue 302210616).
- A **People API** expõe apenas contatos e `contactGroups`; não há conceito de
  "família" nem de membros supervisionados.
- Integrações que existem (ex.: pacote `tducret/familylink`, add-ons de Home
  Assistant) usam **endpoints internos por engenharia reversa**, sem contrato
  de estabilidade e em tensão com os Termos de Serviço do Google — não são
  base aceitável para um produto.
- Contas Google infantis/supervisionadas ainda **limitam** o que o responsável
  autoriza a apps de terceiros; desde mar/2025 o acesso exige OAuth.
- No Android é possível **reimplementar** funções (uso de apps via
  `UsageStatsManager` com `PACKAGE_USAGE_STATS`, políticas via
  `DevicePolicyManager`), mas isso é um produto de controle parental próprio,
  fora do escopo deste app, e sujeito à **Google Play Families Policy**
  (COPPA/LGPD, SDKs de anúncios certificados, sem anúncio personalizado,
  tela neutra de idade).

**Consequência para a arquitetura:**

- A "família" é **gerenciada dentro do app**, associando membros por suas
  contas Google (apenas identidade, via Google Sign-In).
- O app **não sincroniza** com o Family Link; tarefas, pontos e aprovações
  vivem no Firestore do próprio app.
- Se no futuro o Google publicar uma API oficial de famílias, reavaliar.

## Estrutura do repositório

```
children_tasks/
├── lib/
│   ├── main.dart                 # bootstrap: ProviderScope + ChildrenTasksApp
│   └── src/
│       ├── app/                  # MaterialApp, tema, locale, init do Firebase
│       ├── common/               # widgets/utilitários compartilhados
│       ├── data/                 # modelos + repositórios do Firestore (docs/data-model.md)
│       └── features/<feature>/   # uma pasta por feature, dividida em:
│           ├── application/       #   providers Riverpod, casos de uso
│           ├── data/              #   repositórios/fontes específicos da feature
│           ├── domain/            #   modelos específicos da feature
│           └── presentation/      #   telas e widgets
├── test/               # espelha a estrutura de lib/
├── functions/          # Cloud Functions (TypeScript)
├── firestore-tests/    # testes das Security Rules (@firebase/rules-unit-testing)
├── docs/data-model.md  # esquema do Firestore
├── firebase.json firestore.rules firestore.indexes.json .firebaserc
├── android/ ios/ web/ windows/ macos/ linux/   # gerado pelo flutter create
└── README.md
```

Convenções: `application id` / `bundle id` = `br.com.semogdev.childrentasks`;
gerência de estado com **Riverpod**; lints extras em `analysis_options.yaml`;
locale fixo `pt_BR`.

### Flavors

Ambiente selecionado em tempo de compilação por `--dart-define=FLAVOR=dev|prod`
(padrão `dev`). Em `dev` o app usa o **Emulator Suite** por padrão; force com
`--dart-define=USE_FIREBASE_EMULATOR=true|false`.

```bash
flutter run -d web-server --web-port 5000               # dev + emuladores
flutter run --dart-define=FLAVOR=prod                   # prod
```

> A porta 8080 é do emulador do Firestore — rode o app web em outra porta.

### Login Google no Android/iOS

O login web usa popup e não precisa de config extra. Para o **nativo**
(`google_sign_in`), passe o client ID OAuth "Web" do projeto Firebase:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

## Como começar (desenvolvimento)

```bash
# Pré-requisitos: Flutter SDK (>= 3.44), Android Studio / Xcode conforme a plataforma
flutter --version

# Instalar dependências
flutter pub get

# Conferir análise estática e testes
flutter analyze
flutter test

# Rodar (escolha o dispositivo com -d, ex.: chrome)
flutter run
```

### Testes das Security Rules

```bash
firebase emulators:exec --only firestore \
  "npm --prefix firestore-tests test"
```
(ou, com o emulador já rodando: `FIRESTORE_EMULATOR_HOST=localhost:8080 npm --prefix firestore-tests test`)

O app roda sem Firebase (estado de bootstrap). Para ligar o backend, faça a
configuração abaixo.

## Configuração do Firebase

O SDK e a estrutura já estão integrados (issue #4). Falta provisionar os
projetos e gerar os arquivos de options. **Uma vez, por quem tem acesso ao
Google Cloud / Firebase:**

1. Crie dois projetos no [console Firebase](https://console.firebase.google.com):
   um de **dev** e um de **prod**. Habilite em cada um: Authentication
   (provedor Google), Cloud Firestore, Cloud Messaging.
2. Instale as CLIs:
   ```bash
   npm i -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
3. Gere as options de cada flavor (sobrescreve os placeholders versionados):
   ```bash
   flutterfire configure --project=<projeto-dev> \
     --out=lib/src/app/firebase/firebase_options_dev.dart \
     --platforms=android,ios,web,windows,macos

   flutterfire configure --project=<projeto-prod> \
     --out=lib/src/app/firebase/firebase_options_prod.dart \
     --platforms=android,ios,web,windows,macos
   ```
4. Aponte os aliases em `.firebaserc` (`dev`/`prod`) para os ids reais.
5. Cloud Functions:
   ```bash
   cd functions && npm install && npm run build
   ```
6. Rodar tudo local:
   ```bash
   firebase emulators:start           # auth:9099, firestore:8080, functions:5001, UI
   flutter run                        # já conecta nos emuladores em dev
   ```

Não são versionados: `google-services.json`, `GoogleService-Info.plist`
(regeneráveis), service accounts. **São** versionados os
`firebase_options_*.dart` — não são segredos; a segurança fica nas
Security Rules (issue #6).

## Contribuição / fluxo de trabalho

O trabalho é organizado via **GitHub Projects** (sprint harness). Todo pedido
não-trivial vira uma Issue vinculada ao Project antes de ir para o código.

Cada PR roda o workflow **CI** (`.github/workflows/ci.yml`):

| job | o que roda |
| --- | --- |
| Flutter | `flutter analyze` + `flutter test --coverage` |
| Cloud Functions | `npm ci` + `npm run lint` + `npm run build` em `functions/` |
| Firestore Security Rules | `firebase emulators:exec` + testes de `firestore-tests/` |

Recomendado: proteger a branch `main` exigindo esses 3 checks antes do merge
(Settings → Branches → Branch protection rules).

## Licença

[MIT](LICENSE).
