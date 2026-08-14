# Engineering quality

Vivobody’s quality bar is durable state, clear boundaries, native interaction,
and evidence proportional to risk. This document holds conventions that guide
implementation; executable rules remain in scripts and source.

## Product quality

- Never lose workout state. Persist each meaningful interaction and restore an
  active session independently from whether its sheet is visible.
- Optimize for one-handed use and three-foot readability during training.
  Primary controls are at least 44pt and dense lists retain native body sizing.
- Keep the rest timer visible and actionable as a core session state.
- Prefer native iOS behavior and system semantics over custom replicas.
- Use semantic accessibility assertions for automated UI confidence and
  screenshots for visual judgment.

Read [workout-app-principles.md](../workout-app-principles.md) before making UX
decisions; it is the product constitution rather than a component catalog.

## Implementation conventions

- Start with `ScreenKit`, `PanelKit`, `GlassStyle`, and existing input/display
  components before creating a new visual primitive.
- Keep the app dark and use the existing surface and tint vocabulary rather
  than raw material effects.
- Convert weight only at the UI boundary through `WeightFormatter`; store the
  canonical value.
- Use `SettingsKey` instead of literal defaults keys.
- Use a value-type draft when editing a collection of model children; direct
  `@Bindable` editing is appropriate for a single record.
- Use closure-based `NavigationLink { destination } label: { content }` for
  SwiftData-backed destinations.
- Use the native rename and list-edit mechanisms when they meet the behavior;
  do not add decorative controls that duplicate system actions.
- Test drag scrubbers inside a `ScrollView` because their zero-distance gesture
  competes with scrolling.
- Pluralize unit copy from values rather than hardcoding a suffix.

## Code as a map

Every Swift file begins with a purpose header that says why the file exists.
When responsibility moves, update the header. A new reusable component gets an
interactive `*Gallery.swift` beside it under `#if DEBUG` so behavior can be
inspected in isolation.

Prefer one obvious owner for each concern. If a rule can be verified cheaply,
add it to `Scripts/check_architecture.py` with a mutation test instead of
relying on prose alone. Keep exact allowlists, counts, schema versions, and
target settings in their source files rather than copying them into guidance.

### Entropy ratchet

`Scripts/check_source_sizes.py` prevents new oversized production Swift files
and further growth in existing oversized files. The checked-in baseline records
today's debt rather than blessing it: splitting or shrinking a file requires
lowering its allowance so the removed complexity cannot silently return.

`Scripts/quality_scan.py` combines enforced checks with report-only stale-doc,
orphan-screen, and repeated-UI-surface heuristics. Run it manually and review
the report under `.verify/`. Do not schedule it until several maintenance runs
show that the heuristic sections are useful and low-noise.

### Correction routing

When a correction reveals a repeatable failure mode, preserve it at the
smallest durable layer that can prevent recurrence:

| Repeated problem | Permanent home |
|---|---|
| Logic regression | Targeted test |
| Forbidden dependency or call site | Structural lint with a mutation test |
| UI workflow regression | Semantic Baguette scenario |
| Repeated agent procedure | Script first; repository skill only after the script is stable |
| Architectural rationale | Decision record or specification |
| Subjective design preference | Shared component or product design principle |
| General codebase drift | Manual quality scan, scheduled only after it is reliable |

Diagnostics follow the same rule. Use `AppDiagnostics` stable event kinds and
privacy-safe outcomes; never log workout names, exercise names, notes, loads,
URLs, identifiers, or HealthKit sample values.

## Testing

Tests use Swift Testing (`@Test`, `#expect`), `@MainActor` where model graphs
require it, in-memory stores, and fixed `Date` values or virtual clocks. Test
public behavior and invariants. A new insight includes a model test suite; a
new structural rule includes a failing mutation fixture.

Risky serialization boundaries keep compatibility fixtures. Before V1, the
SwiftData fixture proves the current schema can reopen a representative store;
an intentional breaking change may replace it because development data is not
yet a shipped contract. The first public release freezes `SchemaV1` and its
fixture permanently. From then on, every schema must open all retained stores,
and old fixtures are never rewritten to make migrations pass.

A widget snapshot change must cover the current envelope, obsolete versions,
malformed and missing data, and the supported legacy-unversioned payload.
`Scripts/check.sh` verifies `vivobodyTests/Fixtures/SHA256SUMS`, so an accidental
baseline rewrite is always visible.

The verification matrix and commands live in
[verification.md](verification.md).

## Accessibility

Controls need accurate labels, roles, values, enabled state, and tap targets.
Add stable identifiers to harness-critical controls and state surfaces, not to
every decorative view. Scenarios should locate actions semantically and derive
coordinates from the accessibility frame; hardcoded screen coordinates are not
an accepted contract.

## Generated and shared contracts

- `specs/catalog/` is the reviewed catalog source; `Scripts/catalog.py` is the
  only writer of the bundled runtime JSON.
- `Shared.xcconfig` is the only version source for app and extension.
- Widget snapshots are versioned contracts. A payload change updates app
  writer, widget readers, fallbacks, and version together.
- Body-model mesh ownership is load-bearing and remains covered by mapping
  tests; rename only with a coordinated taxonomy, asset, and test change.
