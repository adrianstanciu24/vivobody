//
//  ActiveExerciseCard.swift
//  vivobody
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
    /// Card corner radius. Hoisted to a constant so the clip,
    /// bevel, sheen, and sweep all stay in lockstep.
    static let cardCornerRadius: CGFloat = 28

    let exercise: Exercise
    @Bindable var session: WorkoutSession

    /// SwiftData write context — used to query archived sessions
    /// when checking whether a just-completed set beats every prior
    /// recorded set for this exercise (i.e., is a personal record).
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

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

    /// Drives the per-exercise notes editor sheet.
    @State private var isEditingNotes: Bool = false

    /// User toggle for expanding the full set list when it exceeds
    /// the collapse threshold (pyramid templates with many sets).
    /// Per-exercise state — the toggle resets when the user pages
    /// to a different exercise.
    @State private var setListExpanded: Bool = false

    /// Universal "this exercise is done" green — matches the per-set
    /// completion green so the card-level signal harmonizes with the
    /// rows inside it.
    private let completedGreen = Tint.success

    /// Warm in-progress tint that ties into the global primary
    /// accent. Exercise identity still comes from the muscle-group
    /// dot in the header, but the card's ambient glow reads as the
    /// "hot" focus zone of the screen.
    private let inProgressTint = Tint.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Spacer(minLength: 4)
            plateBlock
            chipsBlock
            Spacer(minLength: 8)
            setList
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
        .topSpecularSheen(cornerRadius: Self.cardCornerRadius, intensity: 0.10, height: 0.42)
        .glassRimBevel(cornerRadius: Self.cardCornerRadius, outerWidth: 0.7, innerInset: 1.2)
        .shadow(
            color: (activeIndex == nil ? completedGreen : inProgressTint).opacity(0.38),
            radius: 28, y: 12
        )
        .shadow(color: .black.opacity(0.55), radius: 8, y: 4)
        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
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
            Text("\(WeightFormatter.string(setToDelete.weight, unit: unit)) · \(setToDelete.reps) reps. This can't be undone.")
        }
        .sheet(isPresented: $isEditingNotes) {
            NotesEditorSheet(
                title: "\(exercise.name) Notes",
                placeholder: "Form cues, plate setup, how it felt…",
                initialValue: exercise.notes,
                onSave: { newNotes in exercise.notes = newNotes }
            )
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
                    .font(Typography.metricUnit)
                    .foregroundStyle(.white.opacity(0.50))

                Spacer()

                muscleGroupBead
            }

            HStack(alignment: .center, spacing: 10) {
                Text(exercise.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                notesHeaderButton
            }
            .padding(.top, 2)
        }
    }

    /// Muscle-group identifier rendered as a tiny crystalline bead
    /// inside a glass pill. A small spec dot on the colored sphere
    /// sells "this is a 3D bead" rather than a flat fill — the same
    /// reading the rest of the card aims for.
    private var muscleGroupBead: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(exercise.group.accent)
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.30, y: 0.28),
                            startRadius: 0,
                            endRadius: 5
                        )
                    )
                    .frame(width: 9, height: 9)
                Circle()
                    .stroke(Color.black.opacity(0.35), lineWidth: 0.4)
                    .frame(width: 9, height: 9)
            }
            .shadow(color: exercise.group.accent.opacity(0.55), radius: 3, y: 0)

            Text(exercise.group.displayName)
                .font(Typography.sectionLabel)
                .foregroundStyle(exercise.group.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        )
    }

    /// Compact notes affordance in the exercise card header. Tappable
    /// 44pt zone with a smaller visual chip — no real estate spent
    /// on a full button at the bottom of the card. A small accent
    /// dot in the corner indicates "notes exist for this exercise."
    private var notesHeaderButton: some View {
        Button {
            Haptics.soft()
            isEditingNotes = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: exercise.notes.isEmpty
                      ? "square.and.pencil"
                      : "text.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(exercise.notes.isEmpty ? 0.45 : 0.85))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(exercise.notes.isEmpty ? 0.04 : 0.10))
                    )

                if !exercise.notes.isEmpty {
                    Circle()
                        .fill(exercise.group.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(exercise.notes.isEmpty ? "Add notes" : "Edit notes")
    }

    private var plateBlock: some View {
        HStack {
            Spacer()
            VStack(spacing: -8) {
                PlateVisualizer(
                    weight: WeightFormatter.toDisplay(displayedWeight, unit: unit),
                    barWeight: unit.standardBarWeight,
                    unit: unit
                )
                .frame(height: 150)
                // Ground shadow underneath the barbell. Sells "this
                // is sitting on the floor of the card" instead of
                // hovering in space.
                GlassPedestal(width: 240, shadowOpacity: 0.50)
                    .offset(y: -6)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Reps + weight side-by-side scrubbers. Each chip displays
    /// the current value (with inline unit) and rises with a
    /// liquid fill as the value increases — the affordance for
    /// vertical drag-to-scrub. The dedicated tap-to-complete
    /// button lives inside the Sets list as the active row, so
    /// the chips can stay focused on data + adjustment.
    private var chipsBlock: some View {
        HStack(spacing: 10) {
            NumberScrubber(
                value: repsBinding,
                range: 1...30,
                step: 1,
                pointsPerStep: 16,
                unit: "reps",
                label: nil,
                valueFontSize: 32,
                verticalPadding: 14
            )
            WeightScrubber(
                canonicalWeight: weightBinding,
                purpose: .strength,
                label: nil,
                pointsPerStep: 8,
                valueFontSize: 32,
                verticalPadding: 14
            )
        }
        .disabled(activeIndex == nil)
        .opacity(activeIndex == nil ? 0.55 : 1.0)
    }



    /// Maximum total set rows shown in the collapsed state. For
    /// pyramid templates with 5+ sets we hide the tail behind a
    /// "Show all" disclosure to keep the card from overflowing.
    /// Picked 4 (active row + 1 above + 2 below, or equivalent
    /// window) — comfortably fits any iPhone we care about.
    private static let setListCollapsedLimit = 4

    /// Which set indices to render when the list is collapsed.
    /// Strategy: always include the active row + a small window
    /// around it. When the user is mid-exercise this keeps the
    /// most recent completed set and the next pending one in view.
    private var collapsedVisibleIndices: Set<Int> {
        let total = sets.count
        guard total > Self.setListCollapsedLimit else {
            return Set(0..<total)
        }
        let anchor = activeIndex ?? max(0, total - 1)
        var indices: Set<Int> = [anchor]
        // Add 1 row before + 2 rows after the anchor when possible.
        // Tail-heavy because the user cares more about "what's next"
        // than "what's already done."
        if anchor - 1 >= 0 { indices.insert(anchor - 1) }
        if anchor + 1 < total { indices.insert(anchor + 1) }
        if anchor + 2 < total { indices.insert(anchor + 2) }
        return indices
    }

    /// Number of set rows that the collapse hides. Drives the
    /// "Show N more" button label.
    private var hiddenSetCount: Int {
        max(0, sets.count - collapsedVisibleIndices.count)
    }

    /// True when collapse is in effect and there are rows to reveal.
    private var canExpandSetList: Bool {
        !setListExpanded && hiddenSetCount > 0
    }

    /// Index set of rows to render inside the Sets list. The active
    /// row renders as the big SetCompleteButton; non-active rows
    /// render as compact SetSummaryRows so the active set has the
    /// visual weight of a primary call-to-action.
    private var setListVisibleIndices: Set<Int> {
        setListExpanded ? Set(0..<sets.count) : collapsedVisibleIndices
    }

    @ViewBuilder
    private var setList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sets")
                    .sectionLabelStyle(0.50)
                Spacer()
                if activeIndex == nil {
                    Text("Exercise complete")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(completedGreen)
                }
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                if setListVisibleIndices.contains(idx) {
                    if idx == activeIndex {
                        activeRow(set: set)
                    } else {
                        SetSummaryRow(
                            index: idx + 1,
                            weight: set.weight,
                            reps: set.reps,
                            isCompleted: set.isCompleted
                        )
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

            if canExpandSetList {
                setListDisclosure(expanding: true, count: hiddenSetCount)
            } else if setListExpanded && sets.count > Self.setListCollapsedLimit {
                setListDisclosure(expanding: false, count: 0)
            }
        }
    }

    /// The active set's tap-to-complete button. Owns the haptic
    /// crescendo, ripple, and checkmark draw-on internally; this
    /// closure handles the workout-state plumbing (PR detect,
    /// pending-completion delay, advance to next card).
    private func activeRow(set: WorkoutSet) -> some View {
        SetCompleteButton(
            reps: set.reps,
            weight: set.weight,
            isComplete: pendingCompletionSetID == set.id,
            intensity: (activeIndex == sets.count - 1) ? .peak : .standard,
            onToggle: { handleSetToggle(set) }
        )
    }

    /// Run the PR-detect + auto-advance pipeline. Holds the visual
    /// "pending" state for 550ms so the button's ripple + green
    /// fill + checkmark draw-on can land before the card moves on.
    private func handleSetToggle(_ set: WorkoutSet) {
        let weight = set.weight
        let reps = set.reps
        let exerciseName = exercise.name

        pendingCompletionSetID = set.id

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))

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
                session.pendingPRValue = WeightFormatter.string(weight, unit: unit, includeUnit: false)
                session.pendingPRDetail = detailLine(
                    exerciseName: exerciseName,
                    reps: reps,
                    kind: prKind
                )
            }

            let exerciseNowDone = exercise.orderedSets.allSatisfy(\.isCompleted)
            if exerciseNowDone {
                let exercises = session.orderedExercises
                let currentIdx = exercises.firstIndex { $0.id == exercise.id } ?? 0
                let nextIdx = currentIdx + 1
                let cardCount = exercises.count + 1
                if nextIdx < cardCount {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        session.activeExerciseIndex = nextIdx
                    }
                }
            }
        }
    }

    /// The "Show N more" / "Show less" toggle row underneath the
    /// set list. Same visual weight as a summary row so it doesn't
    /// pull attention away from the active set.
    private func setListDisclosure(expanding: Bool, count: Int) -> some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                setListExpanded = expanding
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: expanding ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                Text(expanding
                     ? "Show \(count) more set\(count == 1 ? "" : "s")"
                     : "Show less")
                    .font(Typography.sectionLabel)
            }
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .glassChip(cornerRadius: 12)
        }
        .buttonStyle(.plain)
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
            return "\(exerciseName) · New max"
        case .volume:
            return "\(exerciseName) · \(reps) reps"
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        let isComplete = activeIndex == nil
        let accent = isComplete ? completedGreen : inProgressTint
        return ZStack {
            // Slightly cooler black at the bottom, warmer near the
            // top — gives the card body a vertical gradient that
            // reads as a curved glass surface instead of a flat fill.
            LinearGradient(
                colors: [
                    Color(red: 0.085, green: 0.080, blue: 0.090),
                    Color(red: 0.045, green: 0.045, blue: 0.055)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Hot quadrant — the ambient warm light source.
            RadialGradient(
                colors: [
                    accent.opacity(isComplete ? 0.26 : 0.22),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 340
            )

            // Diagonal counter-glow — adds dimension by suggesting
            // a second softer light bouncing off the opposite side.
            RadialGradient(
                colors: [
                    accent.opacity(0.10),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 300
            )

            // Bottom inner shadow — the rim "drops" into the surface
            // it's sitting on, so the lower edge reads as recessed.
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
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
