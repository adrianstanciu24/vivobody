//
//  AppState.swift
//  vivobody
//
//  Top-level @Observable container for shell-only concerns:
//    • which tab is selected
//    • the currently-presented WorkoutSession (transient)
//    • whether the workout sheet is expanded vs. minimized
//    • the planned workout for today
//
//  Persistent history is owned by SwiftData and queried directly by
//  views (HistoryScreen, TodayScreen) via @Query — AppState no
//  longer keeps a `completedSessions` array. On archive, the active
//  session is inserted into the injected modelContext and saved.
//

import SwiftUI
import SwiftData
import Observation

enum AppTab: String, CaseIterable, Hashable {
    case today, history, library, insights, me

    var label: String {
        switch self {
        case .today:    return "Today"
        case .history:  return "History"
        case .library:  return "Library"
        case .insights: return "Insights"
        case .me:       return "Me"
        }
    }

    var icon: String {
        switch self {
        case .today:    return "calendar"
        case .history:  return "clock.arrow.circlepath"
        case .library:  return "books.vertical.fill"
        case .insights: return "chart.bar.fill"
        case .me:       return "person.fill"
        }
    }
}

@Observable
final class AppState {
    var selectedTab: AppTab = .today

    /// The currently-active workout session, if any. Lives transient
    /// (not inserted in the modelContext) until archived. When non-nil
    /// the MiniBar appears in the tab bar's bottom-accessory slot.
    var activeSession: WorkoutSession?

    /// Whether the ActiveWorkoutScreen is presented as a sheet.
    /// False = workout is "minimized" to the MiniBar pill. Independent
    /// of `activeSession` lifetime: a session can exist while expanded
    /// OR minimized; only `dismissActiveWorkout` ends the session.
    var isWorkoutExpanded: Bool = false

    /// Lazily-assigned reference to the SwiftData write context.
    /// AppRoot wires this on first appear; mutations to history go
    /// through here. Held as a weak-ish opt-in so previews that don't
    /// supply a context still build and render.
    var modelContext: ModelContext?

    // MARK: - Workout lifecycle

    /// Start a workout. Optionally provide a `template` session to
    /// repeat its structure (typically the most recent archived
    /// session). When `template` is nil — first launch, or the user
    /// explicitly chose "start fresh" — the workout begins as a blank
    /// canvas and the user builds it from the active screen's empty
    /// state. Either way, every repeated set begins fresh:
    /// `Exercise.freshCopy(of:)` clears completion state.
    func startTodaysWorkout(basedOn template: WorkoutSession? = nil) {
        let plan: [Exercise]
        if let template, !template.orderedExercises.isEmpty {
            plan = template.orderedExercises.map(Exercise.freshCopy(of:))
        } else {
            // Nothing to repeat — start empty. The user adds
            // exercises from the active workout's empty state.
            plan = []
        }
        activeSession = WorkoutSession(exercises: plan, restDuration: preferredRestDuration)
        isWorkoutExpanded = true   // the first action is the moment of intent
    }

    /// Start a workout from a saved template. Each TemplateExercise
    /// spawns a fresh Exercise (uniform `plannedSets` × `plannedReps`
    /// × `plannedWeight`). The template's `lastUsedAt` is stamped and
    /// persisted so the Library list can highlight recent picks.
    func startWorkoutFromTemplate(_ template: WorkoutTemplate) {
        let plan = template.orderedExercises.map(Exercise.init(from:))
        activeSession = WorkoutSession(exercises: plan, restDuration: preferredRestDuration)
        isWorkoutExpanded = true
        template.lastUsedAt = Date()
        try? modelContext?.save()
    }

    /// The user's preferred default rest in seconds, as a TimeInterval.
    /// Read from UserDefaults at session creation time and baked into
    /// the new WorkoutSession — so changing the setting mid-workout
    /// doesn't disrupt an in-progress rest, but every new session
    /// picks up the latest preference.
    private var preferredRestDuration: TimeInterval {
        let seconds = UserDefaults.standard.object(forKey: SettingsKey.defaultRestSeconds) as? Int
            ?? SettingsDefaults.defaultRestSeconds
        return TimeInterval(seconds)
    }

    /// Collapse the active workout into the MiniBar. Session continues.
    func minimizeWorkout() {
        isWorkoutExpanded = false
    }

    /// Expand the MiniBar back to the full ActiveWorkoutScreen.
    func expandWorkout() {
        guard activeSession != nil else { return }
        isWorkoutExpanded = true
    }

    /// Throw the active workout away without archiving. Used when
    /// the user explicitly decided this session shouldn't be
    /// recorded — started by mistake, switched programs mid-warmup,
    /// etc. Any logged sets are lost. Distinct from
    /// `dismissActiveWorkout()`, which auto-archives whenever sets
    /// have been logged.
    func discardActiveWorkout() {
        activeSession = nil
        isWorkoutExpanded = false
    }

    /// Called when the user fully exits the workout — either via the
    /// close button (mid-workout) or the Done button (after the
    /// summary). Sessions with at least one logged set are archived
    /// to SwiftData; empty quits are discarded.
    func dismissActiveWorkout() {
        defer {
            activeSession = nil
            isWorkoutExpanded = false
        }
        guard let session = activeSession, session.totalSets > 0 else { return }

        // Stamp completedAt if the user quit mid-workout without
        // finishing every set. The session's totals reflect what they
        // actually did, and the date marks the moment they walked away.
        if session.completedAt == nil {
            session.completedAt = Date()
        }

        guard let context = modelContext else {
            // No context wired (e.g. preview). Silently drop the
            // archive instead of crashing.
            return
        }
        context.insert(session)
        try? context.save()
    }
}
