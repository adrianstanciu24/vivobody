//
//  WorkoutSession.swift
//  vivobody
//
//  Persistent @Model owner of one workout — in-flight or archived.
//  Sets live on their exercise (`exercise.sets`); the session level
//  rolls up aggregates and exposes the active-set mutations. The
//  in-flight sessions are inserted as drafts immediately while the
//  user is working; AppState stamps completedAt when the user archives
//  the workout so History queries can pick it up.
//

import SwiftData
import SwiftUI

/// Whether a comparable-tonnage subtotal represents all eligible work.
/// Non-comparable and timed exercises are outside this accounting pool,
/// so they do not make an otherwise complete summary partial.
nonisolated enum ComparableTonnageAvailability: Hashable {
    case complete
    case partial
    case unavailable
}

/// Honest comparable tonnage for a workout or collection of workouts.
/// `knownSubtotal` remains useful for partial data, while `availability`
/// prevents callers from presenting that subtotal as the complete total.
nonisolated struct ComparableTonnageSummary: Hashable {
    let knownSubtotal: Double
    let availability: ComparableTonnageAvailability

    static let zero = ComparableTonnageSummary(
        knownSubtotal: 0,
        availability: .complete
    )

    func merging(_ other: ComparableTonnageSummary) -> ComparableTonnageSummary {
        let subtotal = knownSubtotal + other.knownSubtotal
        let hasMissing = availability != .complete || other.availability != .complete
        return ComparableTonnageSummary(
            knownSubtotal: subtotal,
            availability: hasMissing
                ? (subtotal > 0 ? .partial : .unavailable)
                : .complete
        )
    }
}

@Model
final class WorkoutSession: Identifiable {
    #Index<WorkoutSession>(
        [\.completedAt],
        [\.startedAt],
        [\.id],
        [\.completedAt, \.startedAt]
    )
    /// Stable UUID for SwiftUI `.sheet(item:)` and for distinguishing
    /// sessions in history lists. @Model classes also carry an
    /// internal `persistentModelID`; we keep our own UUID so external
    /// references (sample/preview, future cross-device sync, etc.)
    /// stay stable.
    var id: UUID = UUID()

    /// Wall-clock anchor for session duration. Captured at init.
    var startedAt: Date = Date()

    /// Set when the user archives the workout. Stays nil for active
    /// drafts, even after all planned sets are complete, so History
    /// does not show a workout before the user taps Done / Save.
    var completedAt: Date?

    /// Duration (seconds) of each rest interval between sets. Stored
    /// per-session so the user could change defaults over time.
    var restDuration: TimeInterval = 90

    /// User body weight in canonical pounds when this workout began.
    /// Bodyweight exercise resistance must remain historically stable
    /// even when the user later gains or loses weight. Zero means the
    /// user has not logged a measurement yet; it is an unknown sentinel,
    /// not an assumed body mass.
    var bodyweightAtStart: Double = ExerciseLoad.unknownBodyweight

    /// Exercises that make up this session. Cascade-deletes when the
    /// session is removed. Order is determined by `Exercise.sortOrder`
    /// — use `orderedExercises` for UI iteration.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.session)
    var exercises: [Exercise] = []

    // MARK: - Runtime UI state

    //
    // These describe the active in-flight UI state (which exercise is
    // on screen, whether the rest timer is up, count-up animation
    // progress on the summary card). They're persisted alongside the
    // rest of the session because SwiftData's @Transient breaks
    // observation tracking in iOS 26 — setting a @Transient property
    // doesn't trigger view re-renders. The storage cost is trivial
    // (a few extra bytes per archived session) and the values are
    // simply ignored when an archived session is viewed via
    // WorkoutSummaryCard's `isHistorical: true` path.
    var isResting: Bool = false
    var restStartedAt: Date? = nil
    var restEndsAt: Date? = nil
    var activeExerciseIndex: Int = 0
    var summaryAnimatedMinutes: Double = 0
    var summaryAnimatedVolume: Double = 0
    var summaryDidCelebrate: Bool = false

    /// The hero number for the PRCelebration overlay — the load just
    /// hit ("150") for a weight PR, the rep count ("9") for a rep PR.
    /// When non-nil (paired with `pendingPRDetail`), the celebration
    /// overlay renders on the active workout screen. Cleared to nil
    /// on tap-to-dismiss.
    var pendingPRValue: String? = nil

    /// The context line for the PRCelebration — e.g.
    /// "BENCH PRESS · NEW MAX" for a weight PR, "BENCH PRESS ·
    /// AT 225 LB" for a rep PR. Set together with `pendingPRValue`
    /// when a PR is detected; cleared together on dismiss.
    var pendingPRDetail: String? = nil

    /// Unit suffix for the celebration hero — the weight symbol
    /// ("lb"/"kg") for weight PRs, "reps" for rep PRs, nil for
    /// timed-hold PRs (whose value is already a self-describing
    /// "m:ss"). Additive defaulted field. Set together with
    /// `pendingPRValue`.
    var pendingPRUnit: String? = nil

    /// UUID of the `HKWorkout` saved to HealthKit for this session,
    /// if any. Stamped after a successful Tier A write so the save is
    /// idempotent — a session that already carries a UUID is never
    /// written to HealthKit again. Nil for sessions saved before the
    /// integration, or when HealthKit sync is off / unauthorized.
    /// Additive defaulted field — no migration.
    var healthKitWorkoutUUID: UUID? = nil

    init(
        id: UUID = UUID(),
        exercises: [Exercise] = [],
        restDuration: TimeInterval = 90,
        bodyweightAtStart: Double = ExerciseLoad.unknownBodyweight,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.exercises = exercises
        self.restDuration = restDuration
        self.bodyweightAtStart = bodyweightAtStart.isFinite && bodyweightAtStart > 0
            ? bodyweightAtStart
            : ExerciseLoad.unknownBodyweight
        self.startedAt = startedAt
        self.completedAt = nil
    }

    // MARK: - Ordered access

    /// Exercises in stable plan order. Use this everywhere the UI
    /// needs a list — the underlying @Relationship array order is
    /// not guaranteed by SwiftData.
    var orderedExercises: [Exercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Active-set queries

    func activeSetIndex(for exercise: Exercise) -> Int? {
        exercise.orderedSets.firstIndex(where: { !$0.isCompleted })
    }

    func activeSet(for exercise: Exercise) -> WorkoutSet? {
        guard let index = activeSetIndex(for: exercise) else { return nil }
        return exercise.orderedSets[index]
    }

    // MARK: - Mutations

    /// Complete the next pending set and decide what happens next.
    /// The returned outcome is the single source of truth the view
    /// layer choreographs the pager from — rest already started (or
    /// deliberately didn't) by the time this returns.
    @discardableResult
    func completeActiveSet(for exercise: Exercise) -> SetCompletionOutcome {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return .none }
        let completed = ordered[index]
        completed.isCompleted = true

        // Carry the just-logged values onto the remaining pending
        // sets so the next set starts where the user actually worked,
        // not back at the plan. Only sets spawned from the same
        // prescription inherit — deliberate per-set programming
        // (pyramid / wave) keeps its own targets.
        for pending in ordered.dropFirst(index + 1)
            where !pending.isCompleted && pending.sharesPlan(with: completed)
        {
            pending.weight = completed.weight
            pending.reps = completed.reps
            pending.duration = completed.duration
        }

        // completedAt is stamped only on archive. Active drafts stay
        // out of History until the user explicitly saves the workout.

        // Superset choreography: within a round the walk to the
        // partner station replaces rest; the timer only runs between
        // rounds (see Superset.swift).
        if let step = supersetStep(after: exercise) {
            switch step {
            case let .partner(partner):
                return .supersetPartner(partner)
            case let .roundComplete(resume):
                beginRest()
                return .supersetRoundRest(resume: resume)
            case .groupComplete:
                return .exerciseComplete
            }
        }

        // Only start a rest interval if there are more sets to do on
        // THIS exercise. The view layer auto-advances the pager when
        // the exercise's last set lands — that transition (and the
        // walk to the next station, in real life) IS the rest. Going
        // straight from a finished exercise into a 90s overlay over
        // the next exercise's card is more disorienting than helpful.
        let exerciseNowDone = ordered.allSatisfy(\.isCompleted)
        if !exerciseNowDone {
            beginRest()
            return .rest
        }
        return .exerciseComplete
    }

    private func beginRest() {
        let started = Date()
        isResting = true
        restStartedAt = started
        restEndsAt = started.addingTimeInterval(restDuration)
    }

    func updateActiveWeight(for exercise: Exercise, weight: Double) {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return }
        ordered[index].weight = exercise.trackedWeight(weight)
    }

    func updateActiveReps(for exercise: Exercise, reps: Int) {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return }
        ordered[index].reps = reps
    }

    /// Set the active (timed) set's hold length. Counterpart to
    /// `updateActiveReps` for `.duration` exercises.
    func updateActiveDuration(for exercise: Exercise, duration: TimeInterval) {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return }
        ordered[index].duration = duration
    }

    /// Set the active set's reps-in-reserve (0…5) — how hard the set
    /// was pushed. Companion to `updateActiveReps`; meaningful only
    /// for `.reps` exercises.
    func updateActiveRIR(for exercise: Exercise, rir: Int) {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return }
        ordered[index].repsInReserve = rir
        ordered[index].rirLogged = true
    }

    func skipRest() {
        isResting = false
        restStartedAt = nil
        restEndsAt = nil
    }

    /// Snap the rest deadline to now without leaving the rest state.
    /// The overlay's first skip swipe zeroes the countdown but keeps
    /// the Go screen up for a confirming second swipe; external
    /// surfaces (Live Activity, MiniBar, rest notification) read this
    /// deadline and must see the same zero, or a later extension
    /// compounds on the stale deadline.
    func zeroRestDeadline() {
        guard isResting else { return }
        restEndsAt = Date()
    }

    /// Clear in-flight UI state before archiving so stale rest timers,
    /// PR celebration values, and summary animation flags don't
    /// persist forever on the archived session. Called at archive
    /// time in WorkoutSessionController.dismissActiveWorkout.
    func resetTransientState() {
        isResting = false
        restStartedAt = nil
        restEndsAt = nil
        pendingPRValue = nil
        pendingPRDetail = nil
        pendingPRUnit = nil
        summaryAnimatedMinutes = 0
        summaryAnimatedVolume = 0
        summaryDidCelebrate = false
    }

    /// Time left on the current rest interval, in seconds. Zero when
    /// not resting or when the deadline has passed. Both the rest
    /// overlay and the MiniBar derive their countdowns from this.
    var restRemaining: TimeInterval {
        guard isResting else { return 0 }
        if let restEndsAt {
            return max(0, restEndsAt.timeIntervalSinceNow)
        }
        guard let start = restStartedAt else { return 0 }
        return max(0, restDuration - Date().timeIntervalSince(start))
    }

    /// Extend the single session-level rest deadline. Both the full
    /// overlay and MiniBar countdown read `restRemaining`, so they stay
    /// in sync after an extension.
    func didExtendRest(by seconds: TimeInterval) {
        guard isResting else { return }
        let baseDeadline = restEndsAt ?? Date().addingTimeInterval(restRemaining)
        restEndsAt = max(baseDeadline, Date()).addingTimeInterval(seconds)
    }

    // MARK: - Session-level stats

    /// All sets across all exercises, flattened. Used by the rollup
    /// computations below; not intended for direct UI consumption.
    private var allSets: [WorkoutSet] {
        exercises.flatMap(\.sets)
    }

    /// Comparable tonnage and its completeness across completed
    /// dynamic-strength sets and external-load power sets. Each reps
    /// set uses effective load, so added body weight and assistance have
    /// the correct polarity. Timed and non-comparable work are excluded
    /// rather than treated as missing.
    var comparableTonnageSummary: ComparableTonnageSummary {
        exercises.reduce(.zero) { summary, exercise in
            summary.merging(exercise.comparableTonnageSummary)
        }
    }

    /// Workout-receipt volume. Comparable exercises contribute their
    /// effective resistance; non-comparable dynamic-strength work
    /// contributes the resistance the user explicitly logged. The
    /// stricter `comparableTonnageSummary` remains the analytics source.
    var totalVolume: Double {
        receiptTonnageSummary.knownSubtotal
    }

    /// User-facing workout volume. Band and other non-comparable
    /// resistance is meaningful inside the workout where it was logged,
    /// even though it must not enter cross-exercise strength analytics.
    var receiptTonnageSummary: ComparableTonnageSummary {
        let loggedNonComparable = exercises.reduce(0.0) { total, exercise in
            guard exercise.loadMode == .nonComparable else { return total }
            return total + (exercise.completedReceiptTonnage ?? 0)
        }
        let loggedSummary = ComparableTonnageSummary(
            knownSubtotal: loggedNonComparable,
            availability: .complete
        )
        return comparableTonnageSummary.merging(loggedSummary)
    }

    var totalReps: Int {
        exercises.reduce(0) { acc, ex in
            guard ex.trackingMode == .reps else { return acc }
            return acc + ex.sets
                .filter(\.isCompleted)
                .reduce(0) { $0 + $1.reps }
        }
    }

    /// Total elapsed work across completed sets of every duration-tracked
    /// exercise.
    var totalTimedWork: TimeInterval {
        exercises.reduce(0) { acc, ex in
            guard ex.trackingMode == .duration else { return acc }
            return acc + ex.sets
                .filter(\.isCompleted)
                .reduce(0) { $0 + $1.duration }
        }
    }

    var totalSets: Int {
        allSets.filter(\.isCompleted).count
    }

    var totalPlannedSets: Int {
        allSets.count
    }

    /// Returns the single representative "top set" for an exercise.
    /// Record-eligible work uses the same shared comparison as live and
    /// history PRs: dynamic/external-power load then reps, comparable
    /// isometric load then duration, duration-only isometrics by hold.
    /// Other work keeps an ordinary display-oriented representative set.
    func topSet(for exercise: Exercise) -> WorkoutSet? {
        exercise.representativeTopSet
    }

    /// Live wall-clock duration. When the workout is still in
    /// progress this counts up to `now`; once `completedAt` is
    /// stamped the value is fixed.
    var duration: TimeInterval {
        (completedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var isAllComplete: Bool {
        !exercises.isEmpty && exercises.allSatisfy { ex in
            !ex.sets.isEmpty && ex.sets.allSatisfy(\.isCompleted)
        }
    }

    // MARK: - Sample / preview

    static var sample: WorkoutSession {
        WorkoutSession(exercises: Exercise.samplePlan())
    }

    /// A fully-completed session for previewing the summary card in
    /// "workout complete" state. Backdates `startedAt` by 54 minutes
    /// so the duration reads as something realistic.
    static var sampleCompleted: WorkoutSession {
        let started = Date().addingTimeInterval(-54 * 60)
        let s = WorkoutSession(exercises: Exercise.samplePlan(), startedAt: started)
        for ex in s.exercises {
            for set in ex.sets {
                set.isCompleted = true
            }
        }
        s.completedAt = Date()
        return s
    }
}
