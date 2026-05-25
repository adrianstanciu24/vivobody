# AGENTS.md — vivobody

iOS workout tracker built from scratch in SwiftUI + SwiftData. Dark-themed,
gesture-first, all data on-device. Single developer (astanciu), iterative work.

## Stack
- **iOS 26.4** (Xcode 17, Swift 6) — uses iOS-26 idioms (`@Bindable`, `.toolbar`, `.searchable`, `RenameButton`, `tabBarMinimizeBehavior`)
- **SwiftUI** for all UI; **SwiftData** (`@Model`, `@Query`) for persistence; **Charts** for progress graphs
- No third-party libraries. Native everything.

## Build / Run / Test

All commands run from `/Users/astanciu/Developer/vivobody`:

```bash
# Compile check (zero warnings is the bar; AppIntents.framework warning is benign)
xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build

# Tests (Swift Testing framework, in vivobodyTests/ and vivobodyUITests/)
xcodebuild -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Always compile before declaring a change "done." For UI-affecting changes, also run `Scripts/verify.sh` (see below).

## Visual verification

`Scripts/verify.sh` builds, boots a headless simulator via `baguette`, installs + launches the app, then writes a screenshot + accessibility tree to `.verify/`. Use this **before declaring any UI change done** — it would have caught the NavigationLink loop and the too-small-densities issues on the first try.

```bash
Scripts/verify.sh                # Today screen at launch
TAB=library Scripts/verify.sh    # Tap a tab first (today | history | library | me)
SIMULATOR_NAME='iPhone 16e' Scripts/verify.sh
```

Two outputs per run:
- `.verify/<state>.jpg` — visual screenshot
- `.verify/<state>-ui.json` — accessibility tree (every label, role, frame). The JSON is the killer feature: verify a button exists, a heading is correct, a value matches, all without parsing pixels.

Requires `baguette` (`brew install baguette`). Tab tap coordinates are calibrated for iPhone 17 Pro (402×874 points); adjust the case statement in `verify.sh` if you switch device sizes.

## Project layout

```
vivobody/
├── App/                   # AppRoot (tab shell), AppState (top-level state), SettingsKeys, KeyboardWarmup
├── Models/                # @Model classes + value types (WorkoutSession, WorkoutTemplate, ExerciseCatalogItem,
│                          #   ExerciseProgress, BodyWeight, WeightUnit, WeightFormatter, WeeklyStats)
├── Components/
│   ├── Buttons/           # PrimaryActionButton, SetCompleteButton
│   ├── Containers/        # SwipePager (the paged exercise carousel)
│   ├── Displays/          # DigitTicker, MiniChart, PlateVisualizer, StreakCalendar, BreathingTimer
│   ├── Haptics/           # Haptics enum — tick(), soft(), rigid(), selection()
│   ├── Inputs/            # NumberScrubber, WeightScrubber, NotesEditorSheet, StepSelector
│   ├── Moments/           # PRCelebration overlay
│   └── Navigation/        # ActiveWorkoutMiniBar
├── Screens/
│   ├── Today/             # TodayScreen (start workout from template / blank)
│   ├── ActiveWorkout/     # ActiveWorkoutScreen + cards, sheets, summary, rest timer
│   ├── History/           # HistoryScreen (past sessions)
│   ├── Library/           # LibraryScreen (Templates + Exercises segments), template + exercise editors,
│   │                      #   ExercisePickerSheet, ExerciseDetailScreen, CustomExerciseEditorSheet
│   └── Me/                # Preferences, body weight, progress charts
└── vivobodyApp.swift      # @main entry point; declares the SwiftData schema
```

## Conventions to match

- **Dark theme everywhere** — black backgrounds, white-with-opacity surfaces (`Color.white.opacity(0.04-0.07)` for cards)
- **iOS HIG densities** — 44pt+ tap targets, 17pt body text in lists, 60pt min row height
- **Storage canonical, conversion at UI boundary** — weight stored as lb internally; `WeightFormatter` + `@AppStorage(SettingsKey.weightUnit)` convert at display time
- **Value-type drafts for editing buffers** when editing collections of @Model children (see `TemplateDraft.swift`); direct `@Bindable` for single-record edits
- **Additive @Model fields with default values** — no migrations needed for new optional/defaulted properties
- **Pluralize unit suffixes** — "1 set" vs "2 sets" via computed strings, not hardcoded
- **Comment headers** at the top of every Swift file explaining the file's purpose

## Gotchas (learned the hard way)

- **NavigationLink: use closure-based form** `NavigationLink { destination } label: { content }`. The value-based form (`NavigationLink(value:)` + `.navigationDestination(for:)`) is finicky with SwiftData `@Model` objects and only works reliably when registered at the NavigationStack root.
- **`.navigationTitle($binding)` + `.toolbarTitleMenu { RenameButton() }`** is the system-native rename pattern for collection titles. No custom pencil icons needed.
- **`EditButton()`** is the only way to reach drag-to-reorder in standard SwiftUI Lists — but if reorder isn't needed, swipe-to-delete via `.swipeActions` is sufficient and Edit can be omitted.
- **`TemplateEditorScreen.swift` is orphaned** — currently unreachable from any UI surface. Library uses `TemplateDetailScreen` for both creation and editing. Safe to delete in a future cleanup pass.
- **Always test scrubber-style components inside a `ScrollView`** — they use `DragGesture(minimumDistance: 0)` and can compete with scroll gestures if mis-nested.
- **Bundle ID is `astanciu.vivobody`** — required for `xcrun simctl launch`. The output bundle filename `vivobody.app` is a different concept (the `.app` is the bundle extension, not part of the ID).

## Key components reference

| When you need to... | Use |
|---|---|
| Edit a numeric value with drag | `NumberScrubber` (Double binding, range, step) |
| Edit a weight value | `WeightScrubber` (canonical-lb binding; handles unit conversion) |
| Big CTA button | `PrimaryActionButton` |
| Pluck an exercise from the catalog | `ExercisePickerSheet` (presented as sheet) |
| Show a SwiftData detail with stats + chart | follow `ExerciseDetailScreen` shape |
| Trigger haptics | `Haptics.tick()` / `.soft()` / `.rigid()` / `.selection()` |

## Where to start

Read `Models/Workout.swift` and `Models/WorkoutTemplate.swift` first — they define the core domain. Then `App/AppRoot.swift` for the tab structure. Then any screen file for examples of the prevailing style.
