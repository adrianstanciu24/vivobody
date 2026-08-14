<coding_guidelines>
# AGENTS.md — vivobody

Vivobody is a native iOS workout tracker built with SwiftUI and SwiftData. It
is dark-themed, gesture-first, on-device, and maintained iteratively by one
developer. No third-party runtime libraries.

This file is the repository entry point: commands, hard rules, routing, and
the definition of done. Follow links for details instead of expanding this
file with implementation inventories that can drift.

## Read before changing code

| Task | Read |
|---|---|
| Any architecture or data-flow change | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Any user-facing UX change | [workout-app-principles.md](workout-app-principles.md), then [engineering/quality.md](engineering/quality.md) |
| Build, tests, screenshots, or semantic flows | [engineering/verification.md](engineering/verification.md) |
| Reviewing a diff or pull request | [engineering/code-review.md](engineering/code-review.md) |
| Researching or implementing a larger feature | [specs/index.md](specs/index.md) and [engineering/plans/README.md](engineering/plans/README.md) |
| Widgets, Live Activities, or App Group provisioning | [WIDGET_IMPLEMENTATION_NOTES.md](WIDGET_IMPLEMENTATION_NOTES.md) |
| Existing compromises or cleanup | [engineering/tech-debt.md](engineering/tech-debt.md) |

Treat source as canonical for volatile facts:

- persistence shape and policy: `vivobody/App/Persistence.swift` and
  `vivobody/vivobodyApp.swift`;
- target graph: `vivobody.xcodeproj/project.pbxproj` and `VivoKit/Package.swift`;
- versions: `Shared.xcconfig` only;
- exercise catalog: `specs/catalog/` projected by `Scripts/catalog.py`;
- enforced architecture rules: `Scripts/check_architecture.py`;
- source-size allowances: `Scripts/source_size_baseline.json`.

## Hard rules

- The app is the only SwiftData writer. Widgets consume versioned Codable App
  Group snapshots; shared app/widget types belong in `VivoKit`.
- Keep system integrations behind their named boundaries. Route session
  lifecycle effects through `SessionSideEffects` and external entry points
  through `IncomingActionParser` plus the single `handle(_:)` site.
- Session lifetime is independent from presentation lifetime.
  `WorkoutSessionController` owns start, restore, archive, discard, minimize,
  and expand behavior.
- Read the persistence source before changing a model. Preserve the recoverable
  in-memory fallback. Before the first public release, keep one current schema
  with no `VersionedSchema`. Freeze the first version at release; every later
  shipped-store migration requires an execution plan.
- Save with `context.saveOrRollback()` and surface errors. A direct save is
  allowed only for a locally owned transaction where rollback is wrong; keep
  it behind a helper and add
  `// architecture: allow-direct-save -- <reason>` at the call site.
- Use `SettingsKey` for UserDefaults keys and `WeightFormatter` for unit
  conversion at the UI boundary. Stored weight remains canonical pounds.
- Compose UI from `ScreenKit`, `PanelKit`, and `GlassStyle`; use 44pt-or-larger
  controls and stable accessibility identifiers on harness-critical controls.
- Persist every workout interaction. Keep the rest timer first-class and
  thumb-reachable. Do not introduce onboarding wizards, gamification copy, or
  interruptions during a workout.
- Swift files start with an accurate purpose header. Reusable components get a
  nearby DEBUG gallery. Tests use Swift Testing and deterministic clocks.
- Route unified logging through `AppDiagnostics`. Events expose stable kinds
  and outcomes, never user-owned workout or HealthKit values.
- New production Swift files stay within the source-size threshold; existing
  oversized files may only shrink under the checked-in ratchet.
- Preserve user changes in a dirty worktree. Do not edit unrelated files.

## Commands

Run from the repository root:

```bash
# Canonical non-UI validator: guardrails, generated data, documentation, build
Scripts/check.sh

# Fast architecture pass while iterating
/usr/bin/python3 Scripts/check_architecture.py

# Manual maintenance report (not scheduled)
/usr/bin/python3 Scripts/quality_scan.py --output .verify/quality-scan.md

# Direct compile when isolating a build issue
xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build

# UI evidence for a user-facing change
Scripts/verify.sh

# Declarative multi-step UI flow
SCENARIO=active-restoration Scripts/verify.sh
```

Run relevant targeted unit tests by default when logic changes. Prefer the
smallest suite that covers the changed contract; do not run the full simulator
suite unless the user explicitly requests it. The exact commands, risk matrix,
Baguette workflow, artifacts, and scenario format are in
[engineering/verification.md](engineering/verification.md).

## Definition of done

- The requested behavior and its failure paths are implemented.
- Relevant source headers, architecture docs, specs, and the spec index still
  describe reality; do not copy volatile source facts into this file.
- `Scripts/check.sh` passes with no unexpected warnings.
- Logic changes pass the smallest relevant targeted unit suite. Persistence
  compatibility and VivoKit snapshot contracts are mandatory when those
  boundaries change.
- A UI-affecting change also has inspected screenshot and accessibility-tree
  evidence from `Scripts/verify.sh` or a semantic scenario.
- The final diff is reviewed against [engineering/code-review.md](engineering/code-review.md),
  with unrelated changes left untouched.
- Anything Baguette cannot observe is called out for manual verification.

## Plans and durable decisions

Create a checked-in execution plan only for expensive, risky, or multi-session
work: persistence migrations, HealthKit or StoreKit changes, widgets, watchOS,
large UX changes, and similarly irreversible cross-cutting work. Small changes
do not need ceremonial plans. Active plans live in
`engineering/plans/active/`; move them to `engineering/plans/completed/` when
the result and verification are recorded.

Record a decision in `engineering/decisions/` only when future contributors
need the rationale to avoid reopening a durable architectural choice.
</coding_guidelines>
