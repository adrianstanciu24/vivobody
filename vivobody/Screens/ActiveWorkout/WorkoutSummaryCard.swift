//
//  WorkoutSummaryCard.swift
//  vivobody
//
//  The (N+1)th page in the ActiveWorkout SwipePager — the session
//  "receipt," reached by swiping past the last exercise. Built in the
//  same instrument language as the exercise pages: full-bleed on
//  black, no card, type and whitespace doing the work.
//
//  Architecture:
//    • A tiny status kicker — "In progress" (Volt) / "Complete" (gold).
//    • The HERO: comparable volume, unloaded repetitions, or timed work
//      as a huge monospaced numeral, with partial/unavailable state kept
//      explicit and shown immediately at its final value.
//    • A StatStrip for the core counts (duration, sets, reps, timed) —
//      the same grammar as the History receipt, ruled top and bottom
//      into a band — with the intensity line (density, hard sets) as
//      a dim footer note beneath.
//    • On a completed receipt, a cumulative comparable-load chart against
//      the cached archive average, separated from the receipt metrics.
//    • The exercise list as type rows divided by hairlines, each with
//      its honest work metric and the same gold/dim set pips used on the pages.
//    • Words for verbs: "Add exercise" and a gold "Done" verb
//      button (finishing the session is a completion).
//
//  Two modes share the layout: in-progress (swiped here mid-workout)
//  and complete (every set logged → Done appears, success haptic).
//

import SwiftUI
import VivoKit

struct WorkoutSummaryCard: View {
    @Bindable var session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    /// Optional dismiss callback from the parent shell. When provided
    /// and the workout is complete, the gold Done verb appears.
    var onDone: (() -> Void)? = nil

    /// Optional add-exercise callback. When provided (and not
    /// historical), an "Add exercise" word-button renders above Done.
    var onAddExercise: (() -> Void)? = nil

    /// When true, renders the real final totals without the count-up
    /// or success haptic. Reserved for non-celebratory review.
    var isHistorical: Bool = false

    /// Cached archive comparison supplied by the parent. It appears only on
    /// the completed receipt and never owns a store query itself.
    var loadComparison: WorkoutLoadComparison? = nil

    /// Duration count-up state lives on `session` (not @State) so it
    /// survives view remounts — e.g. minimizing to the MiniBar and
    /// re-expanding.
    private var animatedMinutes: Double {
        get { session.summaryAnimatedMinutes }
        nonmutating set { session.summaryAnimatedMinutes = newValue }
    }

    private var didCelebrate: Bool {
        get { session.summaryDidCelebrate }
        nonmutating set { session.summaryDidCelebrate = newValue }
    }

    private var displayMinutes: Double {
        isHistorical ? session.duration / 60 : animatedMinutes
    }

    private var receiptMetric: WorkoutReceiptMetric {
        session.primaryReceiptMetric(unit: unit, volumeDisplayStyle: .full)
    }

    private var isComplete: Bool {
        session.isAllComplete
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    statusKicker
                        .padding(.top, Space.xs)
                        .powerOn(0)

                    heroMetric
                        .padding(.top, Space.xl)
                        .powerOn(1)

                    statBand
                        .padding(.top, Space.md)
                        .powerOn(2)

                    if SessionIntensityLine.hasContent(session) {
                        SessionIntensityLine(session: session, unit: unit)
                            .padding(.top, Space.md)
                            .powerOn(2)
                    }

                    if isComplete, let loadComparison {
                        Rectangle()
                            .fill(Surface.edge)
                            .frame(height: 1)
                            .padding(.top, Space.xl)
                            .accessibilityHidden(true)

                        WorkoutLoadComparisonChart(
                            comparison: loadComparison,
                            unit: unit
                        )
                        .padding(.top, Space.lg)
                        .powerOn(3)
                    }

                    exerciseList
                        .padding(.top, Space.xl)
                        .powerOn(4)

                    Spacer(minLength: Space.xl)

                    actionArea
                        .padding(.top, Space.xl)
                        .powerOn(5)
                }
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: session.activeExerciseIndex, initial: true) { _, newIndex in
            if !isHistorical, newIndex == session.orderedExercises.count {
                playEntrance()
            }
        }
    }

    // MARK: - Status + hero

    private var statusKicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isComplete ? "Complete" : "In progress")
                .panelLegendType()
                .foregroundStyle(isComplete ? Tint.complete : Tint.inProgress)
            if isHistorical {
                Text(dateString)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private var heroMetric: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(receiptMetric.value)
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                if let qualifier = receiptMetric.qualifier {
                    Text(qualifier)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                }
                if let metricUnit = receiptMetric.unit {
                    Text(metricUnit)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(receiptMetric.label)
                .panelLegend()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(receiptMetric.accessibilityLabel)
    }

    /// The stat strip bracketed by hairlines — a ruled band on the
    /// receipt. The rules are the same weight as the exercise seams
    /// below, so the column reads as one continuous ledger instead of
    /// the strip floating in whitespace.
    private var statBand: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)
            StatStrip(stats: summaryStats, edgeAligned: true)
                // The strip's vertical dividers are height-flexible
                // Rectangles; in this screen-height VStack they soak up
                // spare space and inflate the band. Pin the strip to
                // its content height so only the Spacer below expands.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Space.md)
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    /// The core counts as a StatStrip — the same value-over-label
    /// grammar the History receipt uses, so the live summary and the
    /// record agree. Duration keeps its entrance count-up through
    /// `displayMinutes`; a partial session reads "12/15" over SETS.
    private var summaryStats: [Stat] {
        var stats = [
            Stat(value: "\(Int(displayMinutes.rounded()))", unit: "min", label: "Duration"),
            Stat(value: setsValue, label: "Sets"),
        ]
        if session.totalReps > 0 {
            stats.append(Stat(value: "\(session.totalReps)", label: "Reps"))
        }
        if session.totalTimedWork > 0 {
            stats.append(Stat(value: DurationFormatter.compact(session.totalTimedWork), label: "Timed"))
        }
        return stats
    }

    private var setsValue: String {
        session.totalPlannedSets != session.totalSets
            ? "\(session.totalSets)/\(session.totalPlannedSets)"
            : "\(session.totalSets)"
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(session.orderedExercises.enumerated()), id: \.element.id) { idx, exercise in
                if idx > 0 {
                    // A linked seam wears the superset accent so the
                    // pair reads as one bracket on the receipt.
                    Rectangle()
                        .fill(isLinkedSeam(before: idx) ? Tint.inProgress.opacity(0.35) : Surface.edge)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                exerciseRow(for: exercise)
            }
        }
    }

    private func isLinkedSeam(before index: Int) -> Bool {
        SupersetGrouping.isSeamLinked(at: index - 1, in: session.orderedExercises)
    }

    private func exerciseRow(for exercise: Exercise) -> some View {
        let exerciseSets = exercise.orderedSets
        let completedSetCount = exerciseSets.filter(\.isCompleted).count

        return HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.group.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                HStack(spacing: Space.xs) {
                    // The same chain glyph + A1 tag the cards and the
                    // template editor use — superset membership is part
                    // of the record, so the receipt shows it too.
                    if let tag = session.supersetTag(for: exercise) {
                        Image(systemName: "link")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.inProgress)
                            .accessibilityHidden(true)
                        Text(tag)
                            .font(Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(Tint.inProgress)
                            .accessibilityLabel("Superset position \(tag)")
                    }
                    Text(exercise.name)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: Space.sm)

            Text(exerciseTotalLabel(for: exercise))
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            summaryPips(for: exerciseSets)
        }
        .padding(.vertical, Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(completedSetCount) of \(exerciseSets.count) sets completed")
    }

    private func exerciseTotalLabel(for exercise: Exercise) -> String {
        if exercise.trackingMode == .duration {
            let total = exercise.sets
                .filter(\.isCompleted)
                .reduce(0) { $0 + $1.duration }
            return DurationFormatter.compact(total)
        }
        guard let volume = exercise.completedReceiptTonnage else {
            let reps = exercise.sets
                .filter(\.isCompleted)
                .reduce(0) { $0 + $1.reps }
            return "\(reps) reps"
        }
        return WeightFormatter.volumeString(volume, unit: unit)
    }

    private func summaryPips(for sets: [WorkoutSet]) -> some View {
        HStack(spacing: Space.sm) {
            ForEach(sets) { set in
                if set.isCompleted {
                    Circle()
                        .fill(Tint.complete)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .strokeBorder(Ink.quaternary, lineWidth: 1.5)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private var actionArea: some View {
        VStack(spacing: Space.md) {
            if !isHistorical, let onAddExercise {
                addExerciseButton(onAddExercise: onAddExercise)
            }
            if isComplete, let onDone {
                doneButton(onDone: onDone)
            }
        }
    }

    private func addExerciseButton(onAddExercise: @escaping () -> Void) -> some View {
        Button {
            Haptics.soft()
            onAddExercise()
        } label: {
            Text("Add exercise")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassTinted(interactive: true, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Surface.edgeBright, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add another exercise")
    }

    /// The finish action — completing the whole session, so it wears
    /// the completion accent (gold) and the same verb shape as the
    /// per-set button.
    private func doneButton(onDone: @escaping () -> Void) -> some View {
        Button {
            Haptics.finale()
            onDone()
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text("Done")
                    .font(Typography.title)
                    .tracking(0.4)
                    .foregroundStyle(Tint.onAccent)
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(Typography.headline)
                    .foregroundStyle(Tint.onAccent)
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .frame(maxWidth: .infinity)
            .coloredGlassControl(cornerRadius: Radius.card, fill: Tint.complete, interactive: true)
            .shadow(color: Tint.complete.opacity(0.40), radius: 22, y: 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish workout and return to home")
    }

    // MARK: - Derived strings

    private var dateString: String {
        let date = session.completedAt ?? session.startedAt
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d  ·  h:mm a"
        return f
    }()

    // MARK: - Entrance animation

    private func playEntrance() {
        let fromMin = animatedMinutes
        let targetMin = session.duration / 60

        let minChanged = abs(targetMin - fromMin) >= 0.5

        if !minChanged { return }

        let isFirstVisit = fromMin == 0
        let minDuration = isFirstVisit ? 0.9 : 0.5

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))

            await countUp(
                from: fromMin,
                to: targetMin,
                duration: minDuration,
                set: { animatedMinutes = $0 }
            )

            if isComplete, !didCelebrate {
                Haptics.success()
                didCelebrate = true
            }
        }
    }

    private func countUp(
        from start: Double,
        to target: Double,
        duration: Double,
        set: @escaping (Double) -> Void
    ) async {
        let frameRate: Double = 60
        let steps = max(1, Int(duration * frameRate))
        let stepNs = UInt64(1_000_000_000.0 / frameRate)
        let delta = target - start

        for i in 1 ... steps {
            let t = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 3) // ease-out cubic
            set(start + delta * eased)
            try? await Task.sleep(nanoseconds: stepNs)
        }
        set(target)
    }
}

#Preview("Summary · complete") {
    let session = WorkoutSession.sampleCompleted
    session.activeExerciseIndex = session.orderedExercises.count
    return WorkoutSummaryCard(session: session, onDone: {}, onAddExercise: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}

#Preview("Summary · in progress") {
    let session = WorkoutSession.sample
    if let first = session.orderedExercises.first {
        let setsInOrder = first.orderedSets
        if setsInOrder.count >= 2 {
            setsInOrder[0].isCompleted = true
            setsInOrder[1].isCompleted = true
        }
    }
    session.activeExerciseIndex = session.orderedExercises.count
    return WorkoutSummaryCard(session: session, onAddExercise: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
