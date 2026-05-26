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

    /// Tap-to-complete state for the hero billboard. The billboard
    /// is the primary tap target now that the duplicate "active set"
    /// row has been dropped from the Sets list, so it needs the same
    /// swipe-safe gesture handling — and the same crescendo of
    /// animations — that the old SetCompleteButton used inside the
    /// SwipePager.
    @State private var heroPressScale: CGFloat = 1
    @State private var heroNumberScale: CGFloat = 1
    @State private var heroDragCanceled: Bool = false
    @State private var heroSize: CGSize = .zero
    @State private var heroRippleId: Int = 0
    @State private var heroRipplePoint: CGPoint = .zero

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
        VStack(alignment: .leading, spacing: 14) {
            header
            plateBlock
            heroBlock
            setList
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Surface.edgeBright,
                            Surface.edge.opacity(0.6),
                            Surface.edge.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        )
        .shadow(
            color: (activeIndex == nil ? completedGreen : inProgressTint).opacity(0.35),
            radius: 28, y: 10
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

                HStack(spacing: 6) {
                    Circle()
                        .fill(exercise.group.accent)
                        .frame(width: 7, height: 7)
                    Text(exercise.group.displayName)
                        .font(Typography.sectionLabel)
                        .foregroundStyle(exercise.group.accent)
                }
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
            PlateVisualizer(
                weight: WeightFormatter.toDisplay(displayedWeight, unit: unit),
                barWeight: unit.standardBarWeight,
                unit: unit
            )
            .scaleEffect(0.78, anchor: .center)
            .frame(height: 100)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// The hero block. A single "10 × 105 lb" billboard that *is*
    /// the active set — tap it to mark the set complete. Inline
    /// scrubbers underneath edit reps/weight without competing with
    /// the headline numbers. Removing the duplicate active row from
    /// the Sets list means the headline IS the action.
    private var heroBlock: some View {
        VStack(spacing: 10) {
            heroBillboard
            heroScrubbers
        }
        .opacity(activeIndex == nil ? 0.55 : 1.0)
    }

    private var heroBillboard: some View {
        let isPending = pendingCompletionSetID != nil
        let isExerciseComplete = activeIndex == nil
        let tint: Color = (isPending || isExerciseComplete) ? completedGreen : inProgressTint
        let isFilled = isPending || isExerciseComplete

        return HStack(alignment: .lastTextBaseline, spacing: 14) {
            VStack(spacing: 0) {
                Text("\(displayedReps)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(heroNumberScale)
                Text("reps")
                    .font(Typography.metricUnit)
                    .opacity(0.50)
            }

            Text("×")
                .font(.system(size: 36, weight: .light, design: .rounded))
                .opacity(0.35)
                .padding(.bottom, 14)

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(WeightFormatter.string(displayedWeight, unit: unit, includeUnit: false))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .scaleEffect(heroNumberScale)
                    Text(unit.symbol)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .opacity(0.55)
                        .padding(.bottom, 6)
                }
                Text("weight")
                    .font(Typography.metricUnit)
                    .opacity(0.50)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .foregroundStyle(isFilled ? Color.black : Color.white)
        .background(heroBackground(tint: tint, isFilled: isFilled))
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isFilled)
        .scaleEffect(heroPressScale)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { heroSize = geo.size }
                    .onChange(of: geo.size) { _, new in heroSize = new }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .gesture(heroTapGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayedReps) reps at \(Int(displayedWeight)) \(unit.symbol)")
        .accessibilityHint(isExerciseComplete ? "Exercise complete." : "Double tap to complete this set.")
        .accessibilityAddTraits(isExerciseComplete ? [] : .isButton)
    }

    /// Layered background for the hero. Bottom is the always-on
    /// glass card; on top of that a solid completion pad fades in
    /// during the pending hold (so the card reads as a single
    /// emphatic green panel); above that a radial ripple expands
    /// from the tap point and fades out. Mirrors SetCompleteButton's
    /// signature crescendo, scaled up for the hero's larger surface.
    @ViewBuilder
    private func heroBackground(tint: Color, isFilled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.clear)
                .glassCard(tint: tint)

            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(completedGreen.opacity(0.95))
                .opacity(isFilled ? 1 : 0)

            HeroRipple(
                triggerId: heroRippleId,
                origin: heroRipplePoint,
                color: isFilled ? .white : completedGreen
            )
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private var heroScrubbers: some View {
        HStack(spacing: 10) {
            NumberScrubber(
                value: repsBinding,
                range: 1...30,
                step: 1,
                pointsPerStep: 16,
                unit: "",
                label: "Reps",
                valueFontSize: 18,
                verticalPadding: 8
            )
            WeightScrubber(
                canonicalWeight: weightBinding,
                purpose: .strength,
                label: "Weight",
                pointsPerStep: 8,
                valueFontSize: 18,
                verticalPadding: 8
            )
        }
        .disabled(activeIndex == nil)
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
    /// set IS included — it renders as a slim "Lifting now" marker
    /// (no duplicate numbers, those live in the hero) so the user
    /// can still see all sets accounted for in sequence.
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
                    SetSummaryRow(
                        index: idx + 1,
                        weight: set.weight,
                        reps: set.reps,
                        isCompleted: set.isCompleted,
                        isActive: idx == activeIndex
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

            if canExpandSetList {
                setListDisclosure(expanding: true, count: hiddenSetCount)
            } else if setListExpanded && sets.count > Self.setListCollapsedLimit {
                setListDisclosure(expanding: false, count: 0)
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

    // MARK: - Hero tap gesture

    /// Drag-cancel distance — past this we lock in "this is a swipe,
    /// not a tap" and let the SwipePager take over. Matches the
    /// proven 10pt value from the old SetCompleteButton.
    private static let heroDragCancelDistance: CGFloat = 10

    /// Predicted-end-translation threshold for catching short fast
    /// flicks before they reach the drag-cancel distance.
    private static let heroFlickCancelDistance: CGFloat = 35

    private var heroTapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard activeIndex != nil, pendingCompletionSetID == nil else { return }
                if !heroDragCanceled, isOverHeroDragThreshold(value) {
                    heroDragCanceled = true
                }
                let inside = isInsideHero(value.location)
                let target: CGFloat = (inside && !heroDragCanceled) ? 0.975 : 1
                if heroPressScale != target {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        heroPressScale = target
                    }
                }
            }
            .onEnded { value in
                defer { heroDragCanceled = false }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                    heroPressScale = 1
                }
                guard activeIndex != nil,
                      pendingCompletionSetID == nil,
                      let activeSet = session.activeSet(for: exercise),
                      !heroDragCanceled,
                      !isFlickHero(value),
                      isInsideHero(value.location)
                else { return }
                fireSetCompletion(activeSet, at: value.location)
            }
    }

    private func isInsideHero(_ p: CGPoint) -> Bool {
        guard heroSize.width > 0, heroSize.height > 0 else { return false }
        return p.x >= 0 && p.x <= heroSize.width && p.y >= 0 && p.y <= heroSize.height
    }

    private func isOverHeroDragThreshold(_ value: DragGesture.Value) -> Bool {
        let dx = abs(value.translation.width)
        let dy = abs(value.translation.height)
        return max(dx, dy) > Self.heroDragCancelDistance
    }

    private func isFlickHero(_ value: DragGesture.Value) -> Bool {
        let pdx = abs(value.predictedEndTranslation.width)
        let pdy = abs(value.predictedEndTranslation.height)
        return max(pdx, pdy) > Self.heroFlickCancelDistance
    }

    /// Commit the active set and run the PR-detect + auto-advance
    /// pipeline. Holds the visual "pending" state for 550ms so the
    /// ripple + green fill + number pulse can land before the card
    /// transitions to the next set (or next exercise).
    private func fireSetCompletion(_ set: WorkoutSet, at point: CGPoint) {
        // Capture the about-to-be-completed values now so the PR
        // check after the 550ms animation delay sees the same
        // numbers the user actually saw on the hero.
        let weight = set.weight
        let reps = set.reps
        let exerciseName = exercise.name
        let isPeakSet = (activeIndex == sets.count - 1)

        switch isPeakSet ? SetIntensity.peak : .standard {
        case .standard: Haptics.crescendo()
        case .peak:     Haptics.swell()
        }

        heroRipplePoint = point
        heroRippleId &+= 1
        pendingCompletionSetID = set.id

        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            heroNumberScale = 1.06
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.08)) {
            heroNumberScale = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))

            // Check PR BEFORE marking the set complete so the set
            // itself isn't included in the comparison.
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

            // Auto-advance to the next card if this set finished
            // the current exercise.
            let exerciseNowDone = exercise.orderedSets.allSatisfy(\.isCompleted)
            if exerciseNowDone {
                let exercises = session.orderedExercises
                let currentIdx = exercises.firstIndex { $0.id == exercise.id } ?? 0
                let nextIdx = currentIdx + 1
                let cardCount = exercises.count + 1   // +1 for the summary card
                if nextIdx < cardCount {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        session.activeExerciseIndex = nextIdx
                    }
                }
            }
        }
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
            Color(red: 0.06, green: 0.06, blue: 0.08)

            RadialGradient(
                colors: [
                    accent.opacity(isComplete ? 0.22 : 0.18),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    accent.opacity(0.08),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 280
            )
        }
    }
}

/// Radial ring that expands from the tap point and fades — the
/// signature "yes, you tapped" confirmation borrowed from
/// SetCompleteButton, scaled up for the hero billboard's larger
/// surface. The triggerId pattern lets the parent fire a fresh
/// animation on every tap without re-creating the view.
private struct HeroRipple: View {
    let triggerId: Int
    let origin: CGPoint
    let color: Color

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 80, height: 80)
            .position(origin == .zero ? CGPoint(x: 0, y: 0) : origin)
            .scaleEffect(scale, anchor: .center)
            .opacity(opacity)
            .onChange(of: triggerId) { _, _ in
                scale = 0.2
                opacity = 0.7
                withAnimation(.easeOut(duration: 0.65)) {
                    scale = 5.0
                    opacity = 0
                }
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
