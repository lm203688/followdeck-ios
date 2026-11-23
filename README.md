# FollowDeck

> A deal-stage follow-up copilot for independent service providers: track where each client sits in the
> proposal → quote → contract → delivery → invoice → payment flow, and never drop a commitment or a late payment again.

**Status:** M2 local-first build: clients, follow-ups, deals and interactions with add / edit / complete / cascade delete, local reminders, rule-based next-step suggestions, client search by name / email / phone / tag, App Intents entity pickers, a revenue-risk view, Spotlight indexing for clients and deals, a local-only JSON export share sheet plus CSV tables for clients and follow-ups, a home-screen WidgetKit glance showing overdue / today / upcoming follow-ups, URL-scheme deep links that route to the matching tab, a Today-board overview summary (clients / open deals / overdue / today / upcoming), validated client and deal forms (email, phone and amount checks), a settings/about screen with version info, a local-data summary and a local mailto feedback entry, a pipeline header summarizing open deals and open value grouped by currency, default roster / follow-up / deal ordering (clients by name; pending first by due date, completed last; deals most recently updated first), and last-contact tracking that advances a client's contact time when an interaction is logged or a follow-up is completed. A 1024 placeholder icon is included; the final brand icon is pending. Compiles and 74 unit-tests green on the cloud macOS runner. No signed / uploaded build yet.

## Fixed product constraints (locked)

- **Platform:** Apple ecosystem only (iPhone / iPad, Mac if needed). No Android, no web at launch.
- **Language:** English only — UI, store metadata, marketing and support copy.
- **Regions:** All overseas App Store regions are allowed; **mainland China is excluded**.
- **AI:** Prefer native platform AI integration (Apple Intelligence / Siri AI / App Intents); third-party or
  in-house API key integration is the fallback. Keys are never hard-coded in the client or committed to this repo.
- **Account:** Individual Apple Developer account; membership is active.
- **Backup:** Every important document and decision is archived under `00-备份台账/`; secrets are stored in a
  keychain / password manager and kept out of all tracked files.

## Differentiation (why this is not another personal CRM)

Existing personal CRMs (Hippo, Dextr, CatchUp, Tiny CRM Pro, …) already cover relationship reminders, voice
logging, widgets and Shortcuts. FollowDeck narrows the wedge to:

1. **Deal pipeline by stage** — Lead → Proposal → Quote → Contract → Delivering → Invoiced → Paid / At Risk / Closed.
2. **Revenue-risk view** — stalled proposals, parked quotes, overdue invoices surfaced proactively.
3. **Stage-driven next-step suggestions** — what to do and when, based on stage and time spent.
4. **Knowledge-service context** — tuned to consultants, freelance creatives and independent advisors, not tradespeople or sales teams.

## Build path (no local Mac)

Windows cannot install Xcode or run an iOS simulator. The pipeline writes Swift / SwiftUI and the XcodeGen
project spec here; a cloud macOS runner generates the `.xcodeproj` and compiles for the simulator:

1. Author code and `project.yml` on Windows.
2. Push to GitHub.
3. GitHub Actions `macos-build` job: install XcodeGen → `xcodegen generate` → build for the newest iPhone simulator.
4. Signing, TestFlight upload and review submission are scaffolded but stay disabled until the App Store Connect
   API key and distribution certificate are provisioned as GitHub secrets (never committed).

Milestones, blocking dependencies, the engineering guide and store copy live in the separate private docs repo (see Repository layout below).

## Repository layout

```
.
├── project.yml             # XcodeGen spec; the .xcodeproj is generated on the CI runner, not committed
├── .github/workflows/ci.yml# Validate (Linux) + macOS simulator build; signing lane disabled pending secrets
└── FollowDeck/
    ├── Sources/FollowDeck/
    │   ├── App/            # @main entry point
    │   ├── Models/         # Codable data model
    │   ├── Persistence/    # SwiftData container + store mapping
    │   ├── Features/       # Pipeline / TodayBoard / Clients / FollowUps / Settings
    │   ├── Services/       # Store, reminders, Spotlight, AI, risk/export/widget/deep-link/stats
    │   ├── Intents/        # App Intents + entity queries
    │   └── Info.plist
    ├── Shared/             # Cross-target widget snapshot
    ├── Widgets/FollowDeckWidget/  # WidgetKit extension target
    └── Tests/FollowDeckTests/
```

Strategy, research, pricing, compliance drafts, the backup ledger and `docs/` (ROADMAP, engineering guide,
store copy, privacy draft) live in the separate private docs repo; this public repo holds source, spec, CI
and this README only.

## Red lines

- Never commit passwords, OTPs, API keys, private keys, provisioning secrets, card/bank details or ID numbers.
- AI-generated suggestions must be labelled as such; amounts, stages and commitments come from user-entered data.
- Templates and copy must be original or commercially licensed; no copied competitor content.

## License / ownership

Internal working repository for the owner. Third-party open-source licenses to be recorded in `00-备份台账/素材授权/`
before any dependency is added.
