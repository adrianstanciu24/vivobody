<coding_guidelines>
# AGENTS.md — vivobody

iOS workout tracker built from scratch in SwiftUI + SwiftData. Dark-themed,
gesture-first, all data on-device. Single developer (astanciu), iterative work.

## Stack
- **iOS 26.5** (Xcode 17, Swift 6) — uses iOS-26 idioms (`@Bindable`, `.toolbar`, `.searchable`, `RenameButton`, `tabBarMinimizeBehavior`, Liquid Glass via `.glassEffect()`)
- **SwiftUI** for all UI; **SwiftData** (`@Model`, `@Query`, versioned schema) for persistence; **Charts** for progress graphs; **SceneKit** for the 3D body model
- System frameworks in play: **WidgetKit** + **ActivityKit** (widgets, Live Activity, Control Center control), **App Intents** (Siri shortcuts, interactive widgets), **CoreSpotlight**, **HealthKit**, **UserNotifications**
- No third-party libraries. Native everything.

## Targets and schemes

| Target | What it is |
|---|---|
| `vivobody` | The app. Main scheme; building it builds everything. |
| `vivobodyWidgets` | Widget extension: home/lock-screen widgets, Live Activity + Dynamic Island, Control Center control. Bundle id `astanciu.vivobody.app.widgets`. |
| `VivoKit` | Local Swift package shared by app + widgets: design tokens, Codable widget snapshots, ActivityKit attributes, shared App Intents, lightweight weight formatting. |
| `vivobodyTests` / `vivobodyUITests` | Swift Testing unit tests (mostly insights math) + UI tests. |

- App bundle id: `astanciu.vivobody.app`. URL scheme: `vivobody://`. App Group: `group.astanciu.vivobody`.
- `Shared.xcconfig` holds `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for both targets so they can never diverge (ITMS-90473). Bump versions there, nowhere else.
- See `WIDGET_IMPLEMENTATION_NOTES.md` for entitlements/provisioning details.

## Build / Run / Test

All commands run from `/Users/astanciu/Developer/vivobody`:

```bash
# Default validator: compile without booting a simulator
# (zero warnings is the bar; AppIntents.framework warning is benign)
xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build

# Full tests, only when explicitly requested
xcodebuild -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Targeted test suite, preferred over the full suite when explicitly requested
xcodebuild -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:vivobodyTests/TrainingLoadTests
```

Always compile before declaring a change "done." Do not run simulator test suites by default; the user will manually verify behavior that Baguette cannot observe. For UI-affecting changes, run `Scripts/verify.sh` and inspect its screenshot plus accessibility tree. Run full or targeted tests only when the user explicitly requests them.

## Visual verification

`Scripts/verify.sh` incrementally builds, reuses a headless simulator through `baguette`, installs + launches a deterministic app state, then writes a screenshot + accessibility tree to `.verify/`. Use this before declaring any UI change done. This is the default runtime verification path; do not open Simulator.app or fall back to simulator-driven test suites when Baguette cannot verify a flow.

```bash
Scripts/verify.sh                       # Today screen at launch
TAB=insights Scripts/verify.sh          # Launch directly into a tab
CAPTURE_ONLY=1 Scripts/verify.sh         # Capture the running app without rebuilding/relaunching
CLEAN_BUILD=1 Scripts/verify.sh          # Explicitly discard the build cache
RESET_STATE=0 Scripts/verify.sh          # Preserve app data instead of using a deterministic reset
SIMULATOR_NAME='iPhone 16e' Scripts/verify.sh
SIMULATOR_OS=26.2 Scripts/verify.sh
LAUNCH_ARGS='--seed-history' Scripts/verify.sh   # launch with seeded data (see Debug seeding)
```

Two outputs per run:
- `.verify/<state>.jpg` — visual screenshot
- `.verify/<state>-ui.json` — accessibility tree (every label, role, frame). The JSON is the killer feature: verify a button exists, a heading is correct, a value matches, all without parsing pixels.

The default run preserves DerivedData, reuses the booted device, avoids uninstalling the app, waits for the Vivobody accessibility tree, and launches with `--ui-test-reset` so onboarding cannot block checks. `TAB` uses the debug-only `--verify-tab` launch argument instead of flaky coordinate taps. `CAPTURE_ONLY=1` is the fastest loop after interacting through the Baguette UI (`baguette serve`); when combined with `TAB`, it validates that the requested tab is already visible rather than navigating. Anything not visible in the screenshot or accessibility tree is left for user verification.

Requires `baguette` (`brew install baguette`).

## Debug seeding

DEBUG builds accept launch arguments (see `App/DebugSeed.swift`), useful for screenshots and testing data-dependent UI:
- `--seed-history` — realistic multi-week workout history
- `--seed-showcase` — data tuned so every insight section renders
- `--seed-pr` — sets a user up one rep away from a personal record

## Project layout

```
vivobody/                      # app target
├── App/                       # shell + system-integration layer (no screens here)
│   ├── AppRoot.swift          # tab shell: TabView, MiniBar bottom accessory, expanded-workout sheet
│   ├── AppState.swift         # shell-only state (tab selection, Spotlight presentation)
│   ├── WorkoutSessionController.swift  # active-session lifecycle: start/restore/discard/archive/minimize
│   ├── SessionSideEffects.swift        # single fan-out for session events (LiveActivity, HealthKit, widgets…)
│   ├── IncomingAction.swift   # every external entry point (URL, Handoff, Spotlight, widget/Siri mailboxes)
│   │                          #   parses into one enum, dispatched through one handle(_:) site
│   ├── SchemaVersioning.swift # SchemaV1/V2 + migration plan + StorageHealth in-memory-fallback flag
│   ├── WidgetSnapshotWriter.swift      # SwiftData → App Group Codable snapshots for widgets
│   ├── WorkoutLiveActivityController.swift, RestNotificationController.swift,
│   ├── SpotlightIndexer.swift, AppShortcuts.swift, UserActivity.swift,
│   ├── SaveError.swift        # ModelContext.saveOrRollback() — use it for every save
│   ├── GlassStyle.swift       # Liquid Glass surface vocabulary (shapes + tints over .glassEffect())
│   └── SettingsKeys.swift, KeyboardWarmup.swift, DebugSeed.swift
├── Models/
│   ├── Domain/                # @Model classes + value types: Workout(Session), WorkoutTemplate,
│   │                          #   ExerciseCatalog, Muscle (taxonomy → 3D meshes), ExerciseClassification,
│   │                          #   BodyWeight, WeightUnit/WeightFormatter, SetSpecFormatter, CatalogData
│   └── Insights/              # pure analytics, one file per insight: TrainingLoad (ACWR), Readiness,
│                              #   MuscleVolume/Development, StrengthOutlook, TrainingSignature,
│                              #   ConsistencyReport, IntensityMix, RepRangeMigration, UpNext, WeeklyStats…
│                              #   cached via SessionAnalytics (fingerprint-keyed, shared on AppState)
├── HealthKit/                 # HealthKitWorkoutService — the ONLY file that imports HealthKit
├── Components/
│   ├── Kit/                   # the shared vocabulary — start here before hand-rolling any UI:
│   │                          #   ScreenKit (section headers, stat rows, list rows every tab composes from),
│   │                          #   PanelKit (physical-device look: segments, legends, overdriven light),
│   │                          #   LivingMotion (staggered entrance springs, honors Reduce Motion)
│   ├── Buttons/               # PrimaryActionButton, PrimaryButtonStyle, SetCompleteButton
│   ├── Containers/            # SwipePager (the paged exercise carousel)
│   ├── Displays/              # DigitTicker, MiniChart, PlateVisualizer, StreakCalendar, BreathingTimer,
│   │                          #   BodyModelScene + RotatableBodyModel (SceneKit body), GhostPreview,
│   │                          #   SessionIntensityLine, MilestoneBadge, AmbientForge, SpecimenStage…
│   ├── Haptics/               # Haptics enum + Sounds (custom .caf effects in Resources/Sounds)
│   ├── Inputs/                # NumberScrubber, WeightScrubber, BareScrubber, RIRSelector, StepSelector
│   ├── Moments/               # PRCelebration overlay
│   └── Navigation/            # ActiveWorkoutMiniBar
├── Screens/
│   ├── Today/                 # TodayScreen (3D body hero, start workout), StartWorkoutSheet
│   ├── ActiveWorkout/         # ActiveWorkoutScreen + exercise cards, EditSetSheet, RestTimerOverlay, summary
│   ├── History/               # HistoryScreen, SessionDetailScreen
│   ├── Library/               # Templates + Exercises segments, template/exercise editors, pickers,
│   │                          #   ExerciseDetailScreen, OneRepMaxEditorSheet
│   ├── Insights/              # InsightsScreen + one Section file per insight (Signature, Strength,
│   │                          #   TrainingLoad, Consistency, Symmetry, IntensityMix…)
│   ├── Me/                    # MeScreen, SettingsScreen, body weight, PRs, HealthKitPrimingSheet
│   └── Onboarding/            # one-time single-beat welcome (deliberately not a wizard)
├── Resources/                 # BodyModel.scn (~240 named muscle meshes), catalog.json, Sounds/*.caf
└── vivobodyApp.swift          # @main; versioned ModelContainer + in-memory fallback + recovery view

vivobodyWidgets/               # widget extension: UpNext, Consistency, Signature widgets,
                               #   ActiveWorkoutLiveActivity, StartWorkoutControl, WidgetChrome
VivoKit/                       # local SPM package shared by both targets (tokens, snapshots, intents)
Scripts/verify.sh              # visual verification (above)
specs/                         # research + design docs for larger features (HealthKit tiers, muscle
                               #   model, watchOS research) — check here for prior decisions
workout-app-principles.md      # the design constitution — read before any UX-affecting change
WIDGET_IMPLEMENTATION_NOTES.md # App Group / entitlements / provisioning notes
```

## Architecture rules

- **The app is the only SwiftData writer.** Widgets never open the model store; they read versioned Codable snapshots from `UserDefaults(suiteName: "group.astanciu.vivobody")`, written by `WidgetSnapshotWriter`. Interactive widget buttons use App Intents that set a tiny App Group handoff flag and open the app, where the normal SwiftData path executes.
- **Anything shared with widgets goes in VivoKit**, not in the app target (widgets cannot import the app). Design tokens, snapshot types, ActivityKit attributes, shared intents live there.
- **One boundary per system framework.** `HealthKitWorkoutService` is the only HealthKit import; `IncomingAction`/`IncomingActionParser` is the only external-entry-point parser; `SessionSideEffects` is the only fan-out for session lifecycle events. Add subscribers/sources there, never inline in screens.
- **Session lifetime ≠ presentation lifetime.** `WorkoutSessionController` owns start/restore/archive/discard; `activeSession != nil` drives the MiniBar, `isWorkoutExpanded` drives the sheet. A workout can minimize/expand many times before archive.
- **Schema changes:** additive fields with defaults need nothing. Anything non-additive means a new `SchemaVN` + `MigrationStage` in `SchemaVersioning.swift` (current: V2, empty migration plan). Never crash on container failure — the in-memory fallback + `StorageHealth` + recovery view path already exists; keep it working.
- **Insights are pure functions over sessions**, computed through the `SessionAnalytics` fingerprint cache (session count + newest completedAt) so nothing recomputes per render. New insight = model file in `Models/Insights/` + section in `Screens/Insights/` + a test suite.

## Conventions to match

- **Read `workout-app-principles.md` first for anything UX-facing.** Huge monospaced numerals, one-handed thumb-reach, glanceable from 3 feet, never lose state (persist on every interaction), rest timer is a first-class citizen. No onboarding wizards, no gamification copy.
- **Compose screens from `ScreenKit` / `PanelKit` / `GlassStyle`** — do not hand-roll section headers, stat rows, list rows, or glass surfaces. The Kit exists precisely because screens diverged before.
- **Dark theme everywhere** — black backgrounds, white-with-opacity surfaces (`Color.white.opacity(0.04-0.07)` for cards)
- **iOS HIG densities** — 44pt+ tap targets, 17pt body text in lists, 60pt min row height
- **Storage canonical, conversion at UI boundary** — weight stored as lb internally; `WeightFormatter` + `@AppStorage(SettingsKey.weightUnit)` convert at display time
- **Value-type drafts for editing buffers** when editing collections of @Model children (see `TemplateDraft.swift`); direct `@Bindable` for single-record edits
- **Save via `context.saveOrRollback()`** (SaveError.swift), and surface failures — never bare `try? context.save()`
- **UserDefaults keys only via `SettingsKey`** — no string literals
- **Pluralize unit suffixes** — "1 set" vs "2 sets" via computed strings, not hardcoded
- **Comment headers** at the top of every Swift file explaining the file's purpose — they are the codebase's index; keep them accurate when a file's role changes
- **Component galleries** — interactive `*Gallery.swift` files next to components, wrapped in `#if DEBUG`. Add one when building a new reusable component.
- **Tests use Swift Testing** (`@Test`, `#expect`), `@MainActor` structs, virtual clocks (fixed `Date(timeIntervalSince1970:)`), and build model graphs in memory — follow `TrainingLoadTests.swift` as the template.

## Gotchas (learned the hard way)

- **NavigationLink: use closure-based form** `NavigationLink { destination } label: { content }`. The value-based form (`NavigationLink(value:)` + `.navigationDestination(for:)`) is finicky with SwiftData `@Model` objects and only works reliably when registered at the NavigationStack root.
- **`.navigationTitle($binding)` + `.toolbarTitleMenu { RenameButton() }`** is the system-native rename pattern for collection titles. No custom pencil icons needed.
- **`EditButton()`** is the only way to reach drag-to-reorder in standard SwiftUI Lists — but if reorder isn't needed, swipe-to-delete via `.swipeActions` is sufficient and Edit can be omitted.
- **`TemplateEditorScreen.swift` is orphaned** — currently unreachable from any UI surface. Library uses `TemplateDetailScreen` for both creation and editing. Safe to delete in a future cleanup pass.
- **Always test scrubber-style components inside a `ScrollView`** — they use `DragGesture(minimumDistance: 0)` and can compete with scroll gestures if mis-nested.
- **Bundle ID is `astanciu.vivobody.app`** — required for `xcrun simctl launch`. The output bundle filename `vivobody.app` is a different concept (the `.app` is the bundle extension, not part of the ID).
- **Widget snapshots are versioned** — bump the snapshot version in VivoKit when changing payload shape; widgets must render a sane fallback for missing/old snapshots, never a blank tile.
- **Debounce App Group writes** — `WidgetSnapshotWriter` batches; don't add per-keystroke widget reloads.
- **HealthKit duplicates** — archive writes exactly one HKWorkout through `HealthKitWorkoutService`; route any new save through `SessionSideEffects`, never a second call site.
- **`StorageHealth` is a `@MainActor` singleton** — check `didFallbackToInMemory` before assuming persistence works.
- **BodyModel.scn mesh names are load-bearing** — `Muscle.swift` maps ~20 trainable regions to ~240 mesh names (`Pectoralis_Major_L`, …). Renaming meshes or enum cases breaks highlighting silently; `MuscleMappingTests` guards this.
- **Launch-path work is budgeted** — backfills are gated behind one-time flags, Spotlight reindex is throttled per app version, non-critical work is deferred off first paint. Don't add eager work to app launch.

## Key components reference

| When you need to... | Use |
|---|---|
| Edit a numeric value with drag | `NumberScrubber` (Double binding, range, step) |
| Edit a weight value | `WeightScrubber` (canonical-lb binding; handles unit conversion) |
| Big CTA button | `PrimaryActionButton` |
| Section header / stat row / list row | `ScreenKit` primitives |
| Glass surface | `GlassStyle` wrappers, not raw `.glassEffect()` |
| Pluck an exercise from the catalog | `ExercisePickerSheet` (presented as sheet) |
| Show a SwiftData detail with stats + chart | follow `ExerciseDetailScreen` shape |
| Trigger haptics / sounds | `Haptics.tick()` / `.soft()` / `.rigid()` / `.selection()`; `Sounds` |
| React to session start/archive/discard | add a subscriber in `SessionSideEffects` |
| Handle a new deep link / widget action | extend `IncomingAction` + its parser |
| Share a type with widgets | put it in `VivoKit` |

## Where to start

Read `Models/Domain/Workout.swift` and `Models/Domain/WorkoutTemplate.swift` first — they define the core domain. Then `App/AppRoot.swift` for the tab structure (Today | History | Library | Insights | Me) and `App/WorkoutSessionController.swift` for the session lifecycle. Then any screen file for examples of the prevailing style. For UX decisions, `workout-app-principles.md`; for prior research, `specs/`.
</coding_guidelines>
