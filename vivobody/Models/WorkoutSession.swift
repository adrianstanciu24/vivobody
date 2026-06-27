//
//  WorkoutSession.swift
//  vivobody
//
//  Persistent @Model owner of one workout — in-flight or archived.
//  Sets live on their exercise (`exercise.sets`); the session level
//  rolls up aggregates and exposes the active-set mutations. The
//  in-flight session lives un-inserted while the user is working;
//  AppState calls modelContext.insert(session) on archive.
//

import SwiftUI
import SwiftData

@Model
final class WorkoutSession: Identifiable {
    #Index<WorkoutSession>([\.completedAt])
    /// Stable UUID for SwiftUI `.sheet(item:)` and for distinguishing
    /// sessions in history lists. @Model classes also carry an
    /// internal `persistentModelID`; we keep our own UUID so external
    /// references (sample/preview, future cross-device sync, etc.)
    /// stay stable.
    var id: UUID = UUID()

    /// Wall-clock anchor for session duration. Captured at init.
    var startedAt: Date = Date()

    /// Set the moment the final set of the final exercise is completed.
    /// Stays nil while the workout is in progress.
    var completedAt: Date?

    /// Duration (seconds) of each rest interval between sets. Stored
    /// per-session so the user could change defaults over time.
    var restDuration: TimeInterval = 90

    /// Free-form notes captured for this workout — "felt great",
    /// "shoulder bothered me on press", "stayed late, did extra
    /// curls". Empty by default; surfaced on the Summary card (live
    /// + historical) with an inline editor sheet. Additive — no
    /// migration needed.
    var notes: String = ""

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
    var activeExerciseIndex: Int = 0
    var summaryAnimatedMinutes: Double = 0
    var summaryAnimatedVolume: Double = 0
    var summaryDidCelebrate: Bool = false

    /// The hero number for the PRCelebration overlay — e.g. "150"
    /// for the weight just hit. When non-nil (paired with
    /// `pendingPRDetail`), the celebration overlay renders on the
    /// active workout screen. Cleared to nil on tap-to-dismiss.
    var pendingPRValue: String? = nil

    /// The context line for the PRCelebration — e.g.
    /// "BENCH PRESS · 8 REPS". Set together with `pendingPRValue`
    /// when a PR is detected; cleared together on dismiss.
    var pendingPRDetail: String? = nil

    /// Unit suffix for the celebration hero — the weight symbol
    /// ("lb"/"kg") for strength PRs, nil for timed-hold PRs (whose
    /// value is already a self-describing "m:ss"). Additive defaulted
    /// field. Set together with `pendingPRValue`.
    var pendingPRUnit: String? = nil

    init(
        id: UUID = UUID(),
        exercises: [Exercise] = [],
        restDuration: TimeInterval = 90,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.exercises = exercises
        self.restDuration = restDuration
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

    func completeActiveSet(for exercise: Exercise) {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return }
        ordered[index].isCompleted = true

        // Only start a rest interval if there are more sets to do on
        // THIS exercise. The view layer auto-advances the pager when
        // the exercise's last set lands — that transition (and the
        // walk to the next station, in real life) IS the rest. Going
        // straight from a finished exercise into a 90s overlay over
        // the next exercise's card is more disorienting than helpful.
        let exerciseNowDone = ordered.allSatisfy(\.isCompleted)
        if !exerciseNowDone {
            isResting = true
            restStartedAt = Date()
        }

        // Stamp completedAt the first time every set in every exercise
        // is marked complete. Re-mutating a set after this point won't
        // re-stamp the time.
        if isAllComplete && completedAt == nil {
            completedAt = Date()
        }
    }

    func updateActiveWeight(for exercise: Exercise, weight: Double) {
        let ordered = exercise.orderedSets
        guard let index = ordered.firstIndex(where: { !$0.isCompleted }) else { return }
        ordered[index].weight = weight
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
    }

    /// Time left on the current rest interval, in seconds. Zero when
    /// not resting or when the deadline has passed. Both the rest
    /// overlay and the MiniBar derive their countdowns from this.
    var restRemaining: TimeInterval {
        guard isResting, let start = restStartedAt else { return 0 }
        return max(0, restDuration - Date().timeIntervalSince(start))
    }

    /// BreathingTimer self-extends; this is just a notification hook
    /// in case we want to log or animate something at the session level.
    func didExtendRest(by seconds: TimeInterval) {
        // Intentionally empty for now.
    }

    // MARK: - Session-level stats

    /// All sets across all exercises, flattened. Used by the rollup
    /// computations below; not intended for direct UI consumption.
    private var allSets: [WorkoutSet] {
        exercises.flatMap(\.sets)
    }

    /// Sum of `weight × reps` across all completed sets of `.reps`
    /// exercises. Timed (`.duration`) holds carry no weight×reps
    /// volume — their effort is tracked as `totalHoldTime` instead —
    /// so they're excluded here to keep the headline metric honest.
    var totalVolume: Double {
        exercises.reduce(0) { acc, ex in
            guard ex.trackingMode == .reps else { return acc }
            return acc + ex.sets
                .filter(\.isCompleted)
                .reduce(0) { $0 + $1.weight * Double($1.reps) }
        }
    }

    var totalReps: Int {
        exercises.reduce(0) { acc, ex in
            guard ex.trackingMode == .reps else { return acc }
            return acc + ex.sets
                .filter(\.isCompleted)
                .reduce(0) { $0 + $1.reps }
        }
    }

    /// Total time held across completed sets of every `.duration`
    /// exercise — the timed counterpart to `totalVolume`. Surfaced
    /// alongside volume on the summary only when any holds were
    /// logged, so reps-only sessions read exactly as before.
    var totalHoldTime: TimeInterval {
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
    /// For `.reps` exercises that's the heaviest completed set (reps
    /// as tiebreaker); for `.duration` exercises it's the longest
    /// completed hold (weight as tiebreaker). Used by the summary
    /// card and history detail.
    func topSet(for exercise: Exercise) -> WorkoutSet? {
        let completed = exercise.sets.filter(\.isCompleted)
        switch exercise.trackingMode {
        case .reps:
            return completed.max(by: { (a, b) in
                if a.weight == b.weight { return a.reps < b.reps }
                return a.weight < b.weight
            })
        case .duration:
            return completed.max(by: { (a, b) in
                if a.duration == b.duration { return a.weight < b.weight }
                return a.duration < b.duration
            })
        }
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
