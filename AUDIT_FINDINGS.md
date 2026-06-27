# vivobody Correctness Audit Findings

Date: 2026-06-27

Scope: read-only audit of the SwiftUI + SwiftData app for real user-impacting correctness, data-integrity, workflow, automation, and config bugs. The audit did not run build/test/verify because those commands write build, simulator, or `.verify` artifacts.

## Findings

### 1. Active workouts are memory-only until archive

- Severity: High
- User-visible impact: A crash, force quit, OS kill, or app relaunch loses all active workout progress.
- Evidence: `AppState.activeSession` is transient state only in `vivobody/App/AppState.swift:50`. Workout starts create an uninserted `WorkoutSession` in `vivobody/App/AppState.swift:80` and `vivobody/App/AppState.swift:101`. Insertion happens only during dismiss/archive in `vivobody/App/AppState.swift:174`.
- Why the current code permits the bug: The active workout is held in process memory and is not inserted into SwiftData until the archive path runs, so any app lifecycle interruption before archive drops the session.
- Suggested fix direction: Insert an active draft session at start, mark lifecycle state, and save after meaningful mutations.
- Confidence: High

### 2. Partial workout save path is effectively unreachable

- Severity: High
- User-visible impact: Users who complete some sets but cannot finish must either discard or leave the workout open.
- Evidence: `dismissActiveWorkout()` can archive sessions with any sets in `vivobody/App/AppState.swift:153`, but the visible close path calls discard in `vivobody/Screens/ActiveWorkout/ActiveWorkoutScreen.swift:103`, while the summary finish appears only after full completion in `vivobody/Screens/ActiveWorkout/ActiveWorkoutScreen.swift:307`.
- Why the current code permits the bug: The persistence layer supports partial archive, but the UI only exposes discard during an incomplete workout and done after full completion.
- Suggested fix direction: Add an explicit "Finish here" or "Save workout" path for partially completed sessions.
- Confidence: High

### 3. Exercise history is keyed by mutable display name

- Severity: High
- User-visible impact: Renaming or duplicating a custom exercise can split, merge, or hide history, PRs, and library stats.
- Evidence: Custom exercise edits mutate `item.name` in `vivobody/Screens/Library/CustomExerciseEditorSheet.swift:457`. Progress lookups group by lowercased name in `vivobody/Models/ExerciseProgress.swift:217` and `vivobody/Screens/Library/LibraryScreen.swift:624`. Detail screens also look up by name in `vivobody/Screens/Library/ExerciseDetailScreen.swift:830`.
- Why the current code permits the bug: Historical workout exercises and catalog rows are connected through mutable display text instead of a stable identifier.
- Suggested fix direction: Persist a stable catalog/exercise identifier on workout exercises and migrate lookups to that key.
- Confidence: High

### 4. Editing per-set template exercises silently flattens them

- Severity: High
- User-visible impact: Custom set-by-set programming can be overwritten into uniform sets when an exercise is edited.
- Evidence: Drafts can preserve per-set data in `vivobody/Screens/Library/TemplateDraft.swift:124`, but edit opens `ConfigureExerciseSheet` in `vivobody/Screens/Library/TemplateEditorScreen.swift:242`. That sheet hydrates only uniform fields in `vivobody/Screens/Library/ConfigureExerciseSheet.swift:75` and always returns `isPerSet: false` in `vivobody/Screens/Library/ConfigureExerciseSheet.swift:260`.
- Why the current code permits the bug: The edit sheet cannot represent the per-set draft shape, so saving through it collapses structured per-set data.
- Suggested fix direction: Make the configure sheet per-set aware or block that edit route for per-set exercises.
- Confidence: High

### 5. Verification script can pass a stale app after build failure

- Severity: High
- User-visible impact: UI verification may screenshot an old build and falsely bless a broken change.
- Evidence: `xcodebuild` output is piped through `tee ... || true` in `Scripts/verify.sh:36`. Success is then inferred from an existing app bundle in `Scripts/verify.sh:46`.
- Why the current code permits the bug: A failed build can leave a previous app bundle in the derived data path, and the script continues as long as that stale bundle exists.
- Suggested fix direction: Preserve the real build exit code, clean or isolate derived data per run, and fail if the bundle timestamp predates the build.
- Confidence: High

### 6. Recent set taps can be canceled by navigation or dismissal

- Severity: Medium
- User-visible impact: A user can tap complete, swipe or navigate away during the 550 ms delay, and lose that completion.
- Evidence: Completion is delayed in `vivobody/Screens/ActiveWorkout/ActiveExerciseCard.swift:611`, while `onDisappear` cancels the pending task in `vivobody/Screens/ActiveWorkout/ActiveExerciseCard.swift:114`.
- Why the current code permits the bug: The model mutation is inside a delayed task that is tied to the card view lifecycle.
- Suggested fix direction: Commit the model mutation immediately and delay only animation/celebration, or block dismissal while pending.
- Confidence: High

### 7. Rest timer extension has split sources of truth

- Severity: Medium
- User-visible impact: The overlay can show extended rest while the mini bar advances based on the original deadline.
- Evidence: `RestTimerOverlay` calls `session.didExtendRest(by:)` in `vivobody/Screens/ActiveWorkout/RestTimerOverlay.swift:25`, but that method is empty in `vivobody/Models/WorkoutSession.swift:187`. Mini-bar expiry uses session timestamps in `vivobody/Components/Navigation/ActiveWorkoutMiniBar.swift:71`.
- Why the current code permits the bug: The timer overlay mutates local timer state, but the session state used by other surfaces is not updated.
- Suggested fix direction: Store one session-level rest deadline/duration and derive all timer UI from it.
- Confidence: High

### 8. `completedAt` can become stale after post-completion edits

- Severity: Medium
- User-visible impact: Workout duration and ordering can be wrong if users add or delete work after the first "all complete" moment.
- Evidence: `completedAt` is set once in `vivobody/Models/WorkoutSession.swift:139` and duration freezes from it in `vivobody/Models/WorkoutSession.swift:265`. Adding exercises/sets later is allowed in `vivobody/Screens/ActiveWorkout/ActiveWorkoutScreen.swift:128` and `vivobody/Screens/ActiveWorkout/ActiveExerciseCard.swift:492`.
- Why the current code permits the bug: The model stamps completion when all current sets are complete but does not clear or recompute that timestamp when the session changes afterward.
- Suggested fix direction: Clear/recompute `completedAt` when completion state regresses, or stamp final completion only at archive.
- Confidence: High

### 9. Custom or renamed exercises can vanish from muscle analytics

- Severity: Medium
- User-visible impact: User-created or renamed exercises may not contribute to body-part volume/progress.
- Evidence: Workout exercises resolve muscle involvement by current name in `vivobody/Models/Workout.swift:124`, and catalog lookup also uses name in `vivobody/Models/ExerciseCatalog.swift:313`. Unknown names return empty involvement.
- Why the current code permits the bug: Muscle involvement is not stored with the performed exercise and is instead rederived from a mutable or missing catalog name.
- Suggested fix direction: Snapshot muscle involvement onto the workout exercise or link by stable catalog ID.
- Confidence: Medium

### 10. Duration-only PRs are not marked in history/session UI

- Severity: Medium
- User-visible impact: Time-based exercises can set records without any visible PR marker in history.
- Evidence: History PR detection only considers `topWeight` in `vivobody/Screens/History/HistoryScreen.swift:137`. Session detail does the same in `vivobody/Screens/History/SessionDetailScreen.swift:218`, while progress code has duration-aware logic in `vivobody/Models/ExerciseProgress.swift:341`.
- Why the current code permits the bug: Different UI surfaces derive PR state differently, and history/session screens ignore duration-mode records.
- Suggested fix direction: Centralize PR detection by exercise mode and use it in all history surfaces.
- Confidence: High

### 11. History average RIR counts default unlogged values

- Severity: Medium
- User-visible impact: Weekly effort stats can show fake RIR values for sets where the user never logged RIR.
- Evidence: `WorkoutSet` defaults `repsInReserve` to `2` and tracks `rirLogged` separately in `vivobody/Models/Workout.swift:202`. History average uses all completed rep sets' `repsInReserve` in `vivobody/Screens/History/HistoryScreen.swift:173`.
- Why the current code permits the bug: The aggregate treats the default storage value as user-entered data.
- Suggested fix direction: Include only sets where `rirLogged == true`.
- Confidence: High

### 12. Curated catalog default reps are dropped

- Severity: Medium
- User-visible impact: Seeded exercises with explicit rep defaults behave generically in the app.
- Evidence: The curator accepts per-exercise `reps` data, but runtime defaults derive only from mechanic in `vivobody/Models/ExerciseCatalog.swift:265`.
- Why the current code permits the bug: The catalog pipeline accepts a field that the app model/export path does not preserve.
- Suggested fix direction: Add `defaultReps` to the persisted catalog model/export, or remove unused curator input and tests around it.
- Confidence: Medium

### 13. UI tests do not assert critical workflows

- Severity: Medium
- User-visible impact: Regressions in workout start, set completion, save/discard, template editing, or persistence can pass CI.
- Evidence: The main UI test only launches the app in `vivobodyUITests/vivobodyUITests.swift:25`. Launch tests only screenshot in `vivobodyUITests/vivobodyUITestsLaunchTests.swift:20`.
- Why the current code permits the bug: The test target exercises app launch but does not validate behavior or persisted state for core flows.
- Suggested fix direction: Add UI tests for active workout lifecycle, partial save/discard, template edit/save, and relaunch persistence.
- Confidence: High

### 14. Editing body-weight dates can create duplicate same-day entries

- Severity: Low
- User-visible impact: Charts and logs can show conflicting weights for one day.
- Evidence: Create mode replaces same-day rows in `vivobody/Screens/Me/BodyWeightLogSheet.swift:174`, but edit mode mutates date/weight directly in `vivobody/Screens/Me/BodyWeightLogSheet.swift:186`.
- Why the current code permits the bug: Same-day uniqueness is enforced only for new rows, not for date changes on existing rows.
- Suggested fix direction: Apply the same same-day uniqueness rule when editing.
- Confidence: High

### 15. Bundle ID documentation is stale

- Severity: Low
- User-visible impact: Manual simulator launch/debug commands copied from docs can fail.
- Evidence: `AGENTS.md` says the bundle ID is `astanciu.vivobody` in `AGENTS.md:83`, while project settings use `astanciu.vivobody.app` in `vivobody.xcodeproj/project.pbxproj:306` and the verify script uses the same in `Scripts/verify.sh:22`.
- Why the current code permits the bug: Project configuration and developer documentation drifted apart.
- Suggested fix direction: Update `AGENTS.md` to the actual bundle identifier.
- Confidence: High

### 16. App icon asset appears empty despite project requiring one

- Severity: Low
- User-visible impact: Archive, install, or App Store validation can fail or produce a generic icon.
- Evidence: Build settings require an app icon in `vivobody.xcodeproj/project.pbxproj:288`, while the app icon contents file defines slots without filenames in `vivobody/Assets.xcassets/AppIcon.appiconset/Contents.json:2`.
- Why the current code permits the bug: The project points at an asset catalog entry that does not appear to contain image files.
- Suggested fix direction: Add actual icon image files and filename entries, or remove the requirement for non-release builds.
- Confidence: Medium
