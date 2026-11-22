# FollowDeck

> A deal-stage follow-up copilot for independent service providers: track where each client sits in the
> proposal → quote → contract → delivery → invoice → payment flow, and keep follow-ups and late payments from slipping.

**Status:** M0 design · source skeleton + cloud CI scaffold. No signed or uploaded build yet.

## Product constraints

- **Platform:** Apple ecosystem only (iPhone / iPad; Mac if needed). No Android, no web at launch.
- **Language:** English only — UI, store metadata, marketing and support copy.
- **AI:** Prefer native platform integration (Apple Intelligence / App Intents); third-party or in-house API key
  integration is the fallback. API keys are never hard-coded in the client or committed to this repo.

## Build path (no local Mac)

Windows cannot install Xcode or run an iOS simulator. The pipeline writes Swift / SwiftUI and the XcodeGen project
spec here; a cloud macOS runner generates the `.xcodeproj` and compiles for the simulator.

1. Author code and `project.yml` on Windows.
2. Push to GitHub.
3. CI: Linux validation (paths, secret scan, YAML) → `macos-15` runner installs XcodeGen → `xcodegen generate` →
   build for the newest available iPhone simulator.

Signing, TestFlight upload and review submission are scaffolded but stay disabled until release secrets are
provisioned in repository secrets (never committed to source).

## Repository layout

```
.
├── project.yml                          # XcodeGen spec; the .xcodeproj is generated on the runner, not committed
├── .github/workflows/ci.yml             # Linux validate + macOS simulator build
└── FollowDeck/
    ├── Sources/FollowDeck/
    │   ├── App/            # @main entry point
    │   ├── Models/         # Codable models and stage rules
    │   ├── Features/       # Pipeline / TodayBoard / Clients / FollowUps
    │   ├── Services/       # Store, reminders, AI service
    │   ├── Intents/        # App Intents
    │   ├── Assets.xcassets/
    │   └── Info.plist
    └── Tests/FollowDeckTests/
```

## Red lines

- Never commit passwords, OTPs, API keys, private keys, provisioning secrets, payment or identity details.
- AI-generated outputs are labelled as suggestions; amounts, stages and commitments come from user-entered data.
- Templates and assets must be original or commercially licensed; no copied competitor content.

## Ownership

Internal working repository for the owner. Third-party open-source licenses are recorded before any dependency
is added.
