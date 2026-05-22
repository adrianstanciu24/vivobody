//
//  ActiveExerciseCard.swift
//  workapp
//
//  One card in the SwipePager. Composes the atom suite into a real
//  exercise screen:
//    • Header (index, group, name)
//    • PlateVisualizer for the current weight
//    • NumberScrubber to adjust the active set's weight
//    • Set list with SetCompleteButton on the active row
//    • Compact SetSummaryRows for completed and pending sets
//
//  The card never owns workout state — every mutation goes through
//  the WorkoutSession passed in by the parent screen.
//
//  Completion animation: tapping the active SetCompleteButton holds
//  the just-completed appearance for ~550ms so the ripple + checkmark
//  draw-on can finish, THEN advances the session. The rest-timer
//  overlay appears at that moment.
//

import SwiftUI
import SwiftData

struct ActiveExerciseCard: View {
    let exercise: Exercise
    @Bindable var session: WorkoutSession

    /// SwiftData write context — used to query archived sessions
    /// when checking whether a just-completed set beats every prior
    /// recorded set for this exercise (i.e., is a personal record).
    @Environment(\.modelContext) private var modelContext

    /// Holds the ID of the set whose completion animation is still
    /// playing. While set, the SetCompleteButton renders as complete
    /// even though the session hasn't advanced yet.
    @State private var pendingCompletionSetID: UUID? = nil

    /// When non-nil, presents the EditSetSheet for that completed
    /// set. Driven by the row's long-press contextMenu's "Edit" item.
    @State private var editingSet: WorkoutSet? = nil

    /// When non-nil, the destructive-confirmation alert is shown for
    /// that completed set. Decoupled from `editingSet` so a user can
    /// never accidentally trigger both.
    @State private var deletingSet: WorkoutSet? = nil

    /// Universal "this exercise is done" green — matches the per-set
    /// completion green so the card-level signal harmonizes with the
    /// rows inside it.
    private let completedGreen = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)

    /// Neutral cool tone used by every card while there's still work
    /// left on the exercise. Exercise identity comes from the muscle-
    /// group tag in the header, not from the gradient.
    private let inProgressTint = Color(.sRGB, red: 0.42, green: 0.55, blue: 0.78, opacity: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            plateBlock
            inputBlock
            setList
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .sheet(item: $editingSet) { set in
            EditSetSheet(set: set)
        }
        .alert(
            "Delete this set?",
            isPresented: deleteAlertBinding,
            presenting: deletingSet
        ) { setToDelete in
            Button("Delete", role: .destructive) {
                deleteSet(setToDelete)
            }
            Button("Cancel", role: .cancel) { }
        } message: { setToDelete in
            Text("\(Int(setToDelete.weight)) lb · \(setToDelete.reps) reps. This can't be undone.")
        }
    }

    // MARK: - Edit / delete plumbing

    /// Bridge between an optional-presenting state and `.alert`'s
    /// required `isPresented` boolean. The setter handles the
    /// dismiss-by-tap-outside path (newValue == false) by clearing
    /// the underlying `deletingSet`.
    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingSet != nil },
            set: { if !$0 { deletingSet = nil } }
        )
    }

    /// Remove a completed set from this exercise. The remaining sets'
    /// `sortOrder` is re-packed so indices in the UI stay 1..N. Active
    /// set index recomputes itself (first uncompleted) on next read,
    /// so no manual fix-up is needed there.
    private func deleteSet(_ set: WorkoutSet) {
        guard let idx = exercise.sets.firstIndex(where: { $0.id == set.id }) else { return }
        exercise.sets.remove(at: idx)
        for (i, remaining) in exercise.orderedSets.enumerated() {
            remaining.sortOrder = i
        }
        Haptics.soft()
        deletingSet = nil
    }

    // MARK: - Derived

    private var exerciseIndex: Int {
        // Compare by id rather than reference identity so this stays
        // robust to SwiftData fetches that return different instances
        // for the same logical exercise.
        session.orderedExercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
    }

    private var sets: [WorkoutSet] {
        exercise.orderedSets
    }

    private var activeIndex: Int? {
        session.activeSetIndex(for: exercise)
    }

    private var displayedWeight: Double {
        session.activeSet(for: exercise)?.weight ?? exercise.plannedWeight
    }

    private var displayedReps: Int {
        session.activeSet(for: exercise)?.reps ?? exercise.plannedReps
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { displayedWeight },
            set: { new in session.updateActiveWeight(for: exercise, weight: new) }
        )
    }

    /// Reps live as Int in the model but NumberScrubber scrubs Double.
    /// Round on set to keep the model integer-clean.
    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(displayedReps) },
            set: { new in
                session.updateActiveReps(for: exercise, reps: Int(new.rounded()))
            }
        )
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(format: "%02d / %02d",
                            exerciseIndex + 1,
                            session.orderedExercises.count))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Text(exercise.group.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(exercise.group.accent)
            }

            Text(exercise.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 2)
        }
    }

    private var plateBlock: some View {
        HStack {
            Spacer()
            PlateVisualizer(weight: displayedWeight, unit: .lb)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var inputBlock: some View {
        VStack(spacing: 8) {
            NumberScrubber(
                value: weightBinding,
                range: 0...600,
                step: 5,
                pointsPerStep: 8,
                unit: "lb",
                label: "weight",
                valueFontSize: 40,
                verticalPadding: 14
            )

            NumberScrubber(
                value: repsBinding,
                range: 1...30,
                step: 1,
                pointsPerStep: 16,
                unit: "reps",
                label: "reps",
                valueFontSize: 32,
                verticalPadding: 12
            )
        }
        .disabled(activeIndex == nil)
        .opacity(activeIndex == nil ? 0.5 : 1.0)
    }

    private var setList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SETS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                if activeIndex == nil {
                    Text("EXERCISE COMPLETE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(completedGreen)
                }
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                if idx == activeIndex {
                    activeRow(set: set)
                } else {
                    SetSummaryRow(
                        index: idx + 1,
                        weight: set.weight,
                        reps: set.reps,
                        isCompleted: set.isCompleted
                    )
                    // Long-press to edit or delete — only when the
                    // row represents a completed set. Pending/future
                    // sets are reached for editing by becoming the
                    // active row.
                    .contextMenu {
                        if set.isCompleted {
                            Button {
                                editingSet = set
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deletingSet = set
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func activeRow(set: WorkoutSet) -> some View {
        SetCompleteButton(
            reps: set.reps,
            weight: set.weight,
            isComplete: pendingCompletionSetID == set.id,
            intensity: (activeIndex == sets.count - 1) ? .peak : .standard,
            onToggle: {
                // Capture the about-to-be-completed values now so the
                // PR check after the 550ms animation delay sees the
                // same numbers the user actually saw on the button.
                let weight = set.weight
                let reps = set.reps
                let exerciseName = exercise.name

                pendingCompletionSetID = set.id
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(550))

                    // Check PR BEFORE marking the set complete so the
                    // set itself isn't included in the comparison.
                    let prKind = detectPersonalRecord(
                        exerciseName: exerciseName,
                        weight: weight,
                        reps: reps
                    )

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        session.completeActiveSet(for: exercise)
                    }
                    pendingCompletionSetID = nil

                    if let prKind {
                        // The hero number is always the weight lifted —
                        // that's the "thing you picked up." The detail
                        // line varies by which axis of progression
                        // triggered the PR.
                        session.pendingPRValue = "\(Int(weight))"
                        session.pendingPRDetail = detailLine(
                            exerciseName: exerciseName,
                            reps: reps,
                            kind: prKind
                        )
                    }

                    // Auto-advance to the next card if this set
                    // finished the current exercise. Pager goes to
                    // the next exercise (or the summary card past
                    // the last one). The PR overlay, if up, layers
                    // over the slide so the user dismisses into the
                    // new context.
                    let exerciseNowDone = exercise.orderedSets.allSatisfy(\.isCompleted)
                    if exerciseNowDone {
                        let exercises = session.orderedExercises
                        let currentIdx = exercises.firstIndex { $0.id == exercise.id } ?? 0
                        let nextIdx = currentIdx + 1
                        let cardCount = exercises.count + 1   // +1 for the summary card
                        if nextIdx < cardCount {
                            // Brief pause so the checkmark draw-on
                            // settles before the card glides away.
                            try? await Task.sleep(for: .milliseconds(300))
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                                session.activeExerciseIndex = nextIdx
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: - PR detection

    /// The two transparent axes of progress this app celebrates.
    /// Both use numbers the user already sees on the button — no
    /// hidden formulas like Epley 1RM, which made PRs feel arbitrary.
    private enum PRKind {
        /// Strictly heavier than any prior set on this exercise,
        /// regardless of reps. The classic "new max."
        case weight
        /// Single-set volume (weight × reps) beats every prior set.
        /// Catches "more reps at the same weight" and any rep-range
        /// progression that isn't a pure weight bump.
        case volume
    }

    /// Returns the *kind* of PR a `(weight, reps)` set sets, or nil
    /// if it doesn't beat the user's previous best on this exercise
    /// on either axis. Weight PR takes priority when both fire —
    /// it's the more dramatic event ("I lifted heavier than ever").
    /// History is matched by exercise *name* so it spans every
    /// archived session, plus this session's earlier completed sets.
    private func detectPersonalRecord(
        exerciseName: String,
        weight: Double,
        reps: Int
    ) -> PRKind? {
        // Persisted prior sets — every Exercise across history that
        // matches by name.
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == exerciseName }
        )
        let archivedExercises = (try? modelContext.fetch(descriptor)) ?? []
        let archivedPriorSets = archivedExercises
            .flatMap(\.sets)
            .filter(\.isCompleted)

        // In-flight prior sets — earlier sets on this exercise
        // within the current (un-inserted) session.
        let inSessionPriorSets = exercise.sets.filter(\.isCompleted)

        let allPriorSets = archivedPriorSets + inSessionPriorSets

        // First-ever completed set on this exercise: not a PR, just
        // the baseline. Otherwise users would get a celebration on
        // every set of their first-ever workout.
        guard !allPriorSets.isEmpty else { return nil }

        let maxWeight = allPriorSets.map(\.weight).max() ?? 0
        let maxVolume = allPriorSets
            .map { $0.weight * Double($0.reps) }
            .max() ?? 0
        let candidateVolume = weight * Double(reps)

        // Strict `>` — tying your previous best doesn't celebrate.
        // Weight PR wins precedence over volume PR when both fire.
        if weight > maxWeight { return .weight }
        if candidateVolume > maxVolume { return .volume }
        return nil
    }

    /// Detail line for the PRCelebration's small subtitle. Weight
    /// PRs use the "NEW MAX" framing — the lift is the headline.
    /// Volume PRs surface the weight × reps so the user can see
    /// the exact lift that beat their previous best (typically a
    /// rep gain at a known weight).
    private func detailLine(
        exerciseName: String,
        reps: Int,
        kind: PRKind
    ) -> String {
        switch kind {
        case .weight:
            return "\(exerciseName.uppercased()) · NEW MAX"
        case .volume:
            return "\(exerciseName.uppercased()) · \(reps) REPS"
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        let isComplete = activeIndex == nil
        return ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10)
            LinearGradient(
                colors: [
                    (isComplete ? completedGreen : inProgressTint).opacity(isComplete ? 0.26 : 0.20),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }
}

#Preview("Exercise card · standalone") {
    let session = WorkoutSession.sample
    return ActiveExerciseCard(
        exercise: session.orderedExercises[0],
        session: session
    )
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
