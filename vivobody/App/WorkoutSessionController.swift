//
//  WorkoutSessionController.swift
//  vivobody
//
//  Owns the active workout session's lifecycle: start, restore,
//  discard, archive, minimize / expand. Extracted from AppState so
//  AppState can shrink to shell-only concerns (tab selection,
//  Spotlight presentation). Every side-effect fan-out (LiveActivity,
//  widgets, HealthKit, notifications) routes through
//  SessionSideEffects so adding a future subscriber is one line.
//
//  Also owns active-draft persistence boundaries: semantic interactions
//  save immediately, while scrubber detents remain in memory until the
//  gesture, coast, or scene ends.
//
//  Also the single dispatch site for IncomingAction — the unified
//  enum that normalizes every external entry point (URL scheme,
//  Handoff, Spotlight, widget / Siri mailboxes).
//

import SwiftData
import SwiftUI
import UIKit

@MainActor
@Observable
final class WorkoutSessionController {
    /// The currently-active workout session, if any. Stored as a
    /// SwiftData draft (`completedAt == nil`) from the moment it starts
    /// so progress can be restored after a crash, force quit, or OS
    /// reclaim. When non-nil the MiniBar appears in the tab bar's
    /// bottom-accessory slot.
    var activeSession: WorkoutSession?

    /// A discard requested from the expanded workout. The draft stays
    /// alive until the sheet's dismissal animation finishes so
    /// SwiftData's cascade delete cannot clear the visible exercise
    /// hierarchy and briefly reveal an empty workout.
    private var pendingDiscardSession: WorkoutSession?

    /// Lets AppRoot suppress the MiniBar while the retained draft is
    /// only waiting for the workout sheet to finish dismissing.
    var isDiscardPending: Bool { pendingDiscardSession != nil }

    /// Whether the ActiveWorkoutScreen is presented as a sheet.
    /// False = workout is "minimized" to the MiniBar pill. Independent
    /// of `activeSession` lifetime: a session can exist while expanded
    /// OR minimized; archive and discard paths end the session.
    var isWorkoutExpanded: Bool = false

    /// Surfaces a save failure so AppRoot can present the standard
    /// alert. Non-nil while an error is pending.
    var lastSaveError: SaveErrorBox? = nil

    /// Lazily-assigned reference to the SwiftData write context.
    /// AppRoot wires this on first appear; mutations to history go
    /// through here. Held as an opt-in so previews that don't supply
    /// a context still build and render.
    var modelContext: ModelContext?

    /// Weak back-reference to AppState for tab navigation and
    /// Spotlight presentation. Set by AppRoot after both objects
    /// are created.
    weak var appState: AppState?

    // MARK: - Active draft persistence

    /// Immediate path for semantic workout changes such as completion,
    /// rest edits, page changes, and scene deactivation.
    @discardableResult
    func saveActiveSessionChanges(for sessionID: UUID? = nil) -> Bool {
        guard let activeSession else { return false }
        let expectedSessionID = sessionID ?? activeSession.id
        guard activeSession.id == expectedSessionID else { return false }
        return persistActiveSessionChanges(
            for: expectedSessionID,
            event: .updated
        )
    }

    /// Commit the final in-memory value once a scrub and any coast settle.
    /// Live Activity presentation is debounced independently from this save.
    @discardableResult
    func saveSettledScrub(for sessionID: UUID) -> Bool {
        persistActiveSessionChanges(for: sessionID, event: .scrubSettled)
    }

    @discardableResult
    private func persistActiveSessionChanges(
        for sessionID: UUID,
        event: SessionEvent
    ) -> Bool {
        guard pendingDiscardSession == nil,
              let session = activeSession,
              session.id == sessionID,
              let context = modelContext
        else { return false }

        do {
            try context.saveOrRollback()
            SessionSideEffects.handle(event, session: session, in: context)
            return true
        } catch {
            lastSaveError = SaveErrorBox(error)
            return false
        }
    }

    // MARK: - Rest expiry

    /// End a rest interval whose deadline has passed. The shell drives
    /// this from a single one-second clock while the workout is
    /// minimized, because which bottom bar is on screen depends on the
    /// selected tab — the transition, its haptic, and its announcement
    /// must fire exactly once wherever the user is standing. The
    /// expanded workout's rest overlay owns expiry while it is
    /// presented (a skip-to-zero deliberately waits for confirmation).
    @discardableResult
    func endExpiredRestIfNeeded(now: Date = Date()) -> Bool {
        guard pendingDiscardSession == nil,
              let session = activeSession,
              session.isResting,
              hasRestElapsed(session, now: now)
        else { return false }

        Haptics.swell()
        UIAccessibility.post(
            notification: .announcement,
            argument: "Rest complete. Ready for the next set."
        )
        session.skipRest()
        return saveActiveSessionChanges(for: session.id)
    }

    private func hasRestElapsed(_ session: WorkoutSession, now: Date) -> Bool {
        if let deadline = session.restEndsAt { return now >= deadline }
        guard let started = session.restStartedAt else { return false }
        return now.timeIntervalSince(started) >= session.restDuration
    }

    // MARK: - Restore / resume

    /// Restore the newest unarchived workout draft from disk. Called
    /// once AppRoot wires the model context. The sheet stays minimized
    /// on restore so a relaunch lands calmly on Today with the MiniBar
    /// ready to resume.
    func restoreActiveWorkoutIfNeeded() {
        guard activeSession == nil, let context = modelContext else { return }
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let session = try? context.fetch(descriptor).first else { return }
        activeSession = session
        isWorkoutExpanded = false
        WorkoutLiveActivityController.start(for: session)
        WidgetSnapshotWriter.writeActiveWorkout(in: context)
    }

    /// Resume a specific workout session by UUID, as handed to us by
    /// an NSUserActivity continue (Handoff banner, Siri Suggestion,
    /// or system restore). Fetches the session from SwiftData, sets
    /// it active, switches to Today, and expands the sheet. If the
    /// session is missing or already archived, this is a no-op.
    @discardableResult
    func continueWorkout(with id: UUID) -> Bool {
        guard pendingDiscardSession == nil, let context = modelContext else {
            return false
        }
        if let activeSession {
            guard activeSession.id == id else { return false }
            appState?.selectedTab = .today
            isWorkoutExpanded = true
            return true
        }
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id && $0.completedAt == nil }
        )
        descriptor.fetchLimit = 1
        guard let session = try? context.fetch(descriptor).first else {
            return false
        }
        activeSession = session
        appState?.selectedTab = .today
        isWorkoutExpanded = true
        return true
    }

    // MARK: - Start

    /// Start a workout. Optionally provide a `template` session to
    /// repeat its structure (typically the most recent archived
    /// session). When `template` is nil the workout begins as a blank
    /// canvas.
    func startTodaysWorkout(basedOn template: WorkoutSession? = nil) {
        guard activeSession == nil else {
            isWorkoutExpanded = true
            return
        }
        let plan: [Exercise]
        if let template, !template.orderedExercises.isEmpty {
            plan = template.orderedExercises.map(Exercise.freshCopy(of:))
        } else {
            plan = []
        }
        beginActiveWorkout(with: plan)
    }

    /// Start a fresh workout with the user's first catalog selection
    /// already attached. Today presents the exercise picker before
    /// calling this method, so the normal fresh-start path lands
    /// directly on a usable exercise card instead of an empty canvas.
    func startFreshWorkout(with item: ExerciseCatalogItem) {
        guard activeSession == nil else {
            isWorkoutExpanded = true
            return
        }
        let history = resolvedExerciseHistory()
        let summary = history?[item.historyKey]
            ?? history?[item.legacyHistoryKey]
        let firstExercise = Exercise.fresh(
            from: item,
            history: summary,
            sortOrder: 0
        )
        beginActiveWorkout(with: [firstExercise])
    }

    /// Start a workout from a saved template. Each TemplateExercise
    /// spawns a fresh Exercise, with working values prefilled from
    /// the user's most recent logged version of that exercise (see
    /// `Exercise.fromTemplate(_:history:)`). The template's
    /// `lastUsedAt` is stamped so the Library list can highlight
    /// recent picks.
    func startWorkoutFromTemplate(_ template: WorkoutTemplate) {
        guard activeSession == nil else {
            isWorkoutExpanded = true
            return
        }
        let history = resolvedExerciseHistory()
        let plan = template.orderedExercises.map { templateExercise in
            Exercise.fromTemplate(
                templateExercise,
                history: history?[templateExercise.historyKey]
            )
        }
        beginActiveWorkout(with: plan) {
            template.lastUsedAt = Date()
        }
    }

    /// One O(1)-lookup index shared by every exercise factory in a
    /// startup operation. SessionAnalytics normally serves its
    /// background-built cache; before that is ready it performs one
    /// archive fetch rather than one fetch per exercise.
    private func resolvedExerciseHistory()
        -> [String: ExerciseHistorySummary]? {
        guard let context = modelContext else { return nil }
        return appState?.analytics.resolvedExerciseHistory(in: context)
    }

    /// The user's preferred default rest in seconds, read from
    /// UserDefaults at session creation time and baked into the new
    /// WorkoutSession.
    private var preferredRestDuration: TimeInterval {
        let seconds = UserDefaults.standard.object(forKey: SettingsKey.defaultRestSeconds) as? Int
            ?? SettingsDefaults.defaultRestSeconds
        return TimeInterval(seconds)
    }

    /// Insert and save a new draft workout before showing it. Without
    /// a model context (previews), falls back to an in-memory session.
    private func beginActiveWorkout(
        with plan: [Exercise],
        beforeSave: (() -> Void)? = nil
    ) {
        guard let context = modelContext else {
            let session = WorkoutSession(
                exercises: plan,
                restDuration: preferredRestDuration
            )
            beforeSave?()
            activeSession = session
            isWorkoutExpanded = true
            return
        }

        var bodyweightDescriptor = FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.weight > 0 },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        bodyweightDescriptor.fetchLimit = 1
        let bodyweight = (try? context.fetch(bodyweightDescriptor).first?.weight)
            ?? ExerciseLoad.unknownBodyweight
        let session = WorkoutSession(
            exercises: plan,
            restDuration: preferredRestDuration,
            bodyweightAtStart: bodyweight
        )

        context.insert(session)
        beforeSave?()
        do {
            try context.saveOrRollback()
            activeSession = session
            isWorkoutExpanded = true
            SessionSideEffects.handle(.started, session: session, in: context)
        } catch {
            lastSaveError = SaveErrorBox(error)
        }
    }

    // MARK: - Minimize / expand

    func minimizeWorkout() {
        isWorkoutExpanded = false
    }

    func expandWorkout() {
        guard activeSession != nil else { return }
        isWorkoutExpanded = true
    }

    /// Expand only if there's an active session. Used by the
    /// `resumeWorkout` incoming action.
    func expandIfActive() {
        if activeSession != nil {
            isWorkoutExpanded = true
        }
    }

    // MARK: - Discard / dismiss

    /// Begin throwing the active workout away. The sheet comes down
    /// first; `finalizePendingDiscard()` performs the SwiftData delete
    /// from the sheet's onDismiss callback so cascade deletion never
    /// mutates the hierarchy while it is still visible.
    func discardActiveWorkout() {
        guard let session = activeSession else { return }
        pendingDiscardSession = session
        isWorkoutExpanded = false
    }

    /// Complete a discard after the workout sheet is fully gone.
    /// Swipe-to-minimize also fires the sheet's onDismiss callback,
    /// but is a no-op because it never creates a pending discard.
    func finalizePendingDiscard() {
        guard let session = pendingDiscardSession else { return }
        if let context = modelContext {
            context.delete(session)
            do {
                try context.saveOrRollback()
                SessionSideEffects.handle(.discarded, session: session, in: context)
            } catch {
                pendingDiscardSession = nil
                lastSaveError = SaveErrorBox(error)
                return
            }
        }
        pendingDiscardSession = nil
        activeSession = nil
    }

    /// Called when the user fully exits the workout — either via the
    /// close button (mid-workout) or the Done button (after the
    /// summary). Sessions with at least one logged set are archived
    /// to SwiftData; empty quits are discarded. On save failure the
    /// session is kept alive and `lastSaveError` is set so AppRoot
    /// can surface the standard alert.
    func dismissActiveWorkout() {
        guard let session = activeSession, session.totalSets > 0 else {
            if let session = activeSession, let context = modelContext {
                context.delete(session)
                do {
                    try context.saveOrRollback()
                    SessionSideEffects.handle(.discarded, session: session, in: context)
                } catch {
                    lastSaveError = SaveErrorBox(error)
                    return
                }
            }
            activeSession = nil
            isWorkoutExpanded = false
            return
        }

        if session.completedAt == nil {
            session.completedAt = Date()
        }
        session.resetTransientState()

        guard let context = modelContext else {
            activeSession = nil
            isWorkoutExpanded = false
            return
        }
        do {
            try context.saveOrRollback()
            SessionSideEffects.handle(.archived, session: session, in: context)
            appState?.analytics.invalidate()
            activeSession = nil
            isWorkoutExpanded = false
        } catch {
            lastSaveError = SaveErrorBox(error)
        }
    }

    // MARK: - Complete active set (widget tap)

    /// Complete the active set on the current exercise, triggered by
    /// a widget "Complete set" tap. Saves, fires update side effects,
    /// and brings the workout sheet to the foreground.
    func completeActiveSet() {
        guard let session = activeSession else { return }
        let exercises = session.orderedExercises
        guard exercises.indices.contains(session.activeExerciseIndex) else { return }
        let exercise = exercises[session.activeExerciseIndex]
        let outcome = session.completeActiveSet(for: exercise)
        // Mirror the in-app superset choreography so the sheet opens
        // on the right station (no animation — this runs pre-present).
        switch outcome {
        case .supersetPartner(let target), .supersetRoundRest(resume: let target):
            if let idx = exercises.firstIndex(where: { $0.id == target.id }) {
                session.activeExerciseIndex = idx
            }
        case .rest, .exerciseComplete, .none:
            break
        }
        if saveActiveSessionChanges() {
            appState?.selectedTab = .today
            isWorkoutExpanded = true
        }
    }

    // MARK: - Unified action handler

    /// The single dispatch site for every external entry point.
    /// Each `IncomingAction` parser feeds into this; new deep links
    /// or widget intents add one case here.
    func handle(_ action: IncomingAction) {
        switch action {
        case .openTab(let tab):
            if tab == .insights {
                appState?.presentInsights()
            } else {
                appState?.selectedTab = tab
            }

        case .resumeWorkout:
            appState?.selectedTab = .today
            expandIfActive()

        case .startTodaysWorkout:
            guard let context = modelContext, activeSession == nil else {
                if activeSession != nil { isWorkoutExpanded = true }
                return
            }
            let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
            let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            ))) ?? []
            switch UpNext.compute(templates: templates, sessions: sessions).kind {
            case let .scheduled(template, _, _):
                startWorkoutFromTemplate(template)
            default:
                startTodaysWorkout(basedOn: sessions.first)
            }

        case .startTemplate(let uuid):
            guard let context = modelContext, activeSession == nil else {
                if activeSession != nil { isWorkoutExpanded = true }
                return
            }
            var descriptor = FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { $0.id == uuid }
            )
            descriptor.fetchLimit = 1
            if let template = try? context.fetch(descriptor).first {
                startWorkoutFromTemplate(template)
                appState?.selectedTab = .today
            } else {
                appState?.selectedTab = .library
            }

        case .continueSession(let id):
            continueWorkout(with: id)

        case .showExercise(let uuid):
            guard let context = modelContext else { return }
            var descriptor = FetchDescriptor<ExerciseCatalogItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            descriptor.fetchLimit = 1
            if let item = try? context.fetch(descriptor).first {
                isWorkoutExpanded = false
                appState?.selectedTab = .library
                appState?.presentSpotlightExercise(item)
            } else {
                appState?.selectedTab = .library
            }

        case .completeActiveSet:
            completeActiveSet()

        case .showPaywall:
            // The paywall sheet is bound at AppRoot; anything already
            // presented there (expanded workout, Spotlight detail)
            // must come down first or the presentation is dropped.
            isWorkoutExpanded = false
            appState?.pendingSpotlightExercise = nil
            appState?.pro.isPaywallPresented = true
        }
    }
}
