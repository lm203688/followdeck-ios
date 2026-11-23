# FollowDeck

> A deal-stage follow-up copilot for independent service providers: track where each client sits in the
> proposal → quote → contract → delivery → invoice → payment flow, and never drop a commitment or a late payment again.

**Status:** M2 local-first build: clients, follow-ups, deals and interactions with add / edit / complete / cascade delete, local reminders, rule-based next-step suggestions, client search, App Intents entity pickers, a revenue-risk view, Spotlight indexing for clients and deals, and a local-only JSON export share sheet. A 1024 placeholder icon is included; the final brand icon is pending. Compiles and unit-tests green on the cloud macOS runner. No signed / uploaded build yet.

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

See `docs/ROADMAP.md` for milestones and blocking dependencies, and `docs/engineering.md` for the source layout and layering rules.

## Repository layout

```
.
├── 00-备份台账/            # Backup registry: archived docs, asset ledger, secret index (no secret values)
├── project.yml             # XcodeGen spec; the .xcodeproj is generated on the CI runner, not committed
├── .github/workflows/ci.yml# Validate (Linux) + macOS simulator build; signing lane disabled pending secrets
├── docs/
│   ├── INTENTS.md          # App Intents / system integration manifest
│   ├── IA-and-intents.md   # Screen map, wireframes, data model
│   ├── store-metadata.md   # English App Store listing copy
│   ├── privacy-policy-draft.md
│   ├── geo-faq.md
│   ├── engineering.md
│   └── ROADMAP.md
└── FollowDeck/
    ├── Sources/FollowDeck/
    │   ├── App/            # @main entry point
    │   ├── Models/         # Data model
    │   ├── Features/       # Pipeline / TodayBoard / Clients / FollowUps
    │   ├── Services/       # Store, reminders, AI service
    │   ├── Intents/        # App Intents
    │   └── Info.plist
    └── Tests/FollowDeckTests/
```

## Red lines

- Never commit passwords, OTPs, API keys, private keys, provisioning secrets, card/bank details or ID numbers.
- AI-generated suggestions must be labelled as such; amounts, stages and commitments come from user-entered data.
- Templates and copy must be original or commercially licensed; no copied competitor content.

## License / ownership

Internal working repository for the owner. Third-party open-source licenses to be recorded in `00-备份台账/素材授权/`
before any dependency is added.
