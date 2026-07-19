//
//  TodayScreenSections.swift
//  vivobody
//
//  Section view builders extracted from TodayScreen: the
//  body-model hero + caption, the Up Next recommendation card,
//  and the consistency / last-workout journal sections.
//

import VivoKit
import SwiftUI
import SwiftData

extension TodayScreen {
    // MARK: - Sections

    /// Anatomical body model — the screen's hero and the subject of
    /// the readiness section below. Edge-to-edge; drag horizontally
    /// to rotate, vertical drags fall through to the scroll. Lit by
    /// how developed each muscle is (vivid orange where you've trained
    /// hard, fading toward a muted tone where you've eased off), so it
    /// reads as your body, not a mannequin. Mounted on the specimen
    /// stage (turntable + faceplate graticule, see SpecimenStage) so
    /// the figure stands inside the instrument instead of floating on
    /// the void.
    func bodyModelHero(height: CGFloat, state: MuscleDevelopment.State) -> some View {
        StagedBodyModel(
            renderHeight: height,
            channels: state.nodeChannels,
            warmth: completedSessions.forgeWarmth
        )
            .padding(.horizontal, -Space.gutter)
            .accessibilityElement()
            .accessibilityLabel("Your body, coloured by how developed each muscle is — a vivid orange where you've trained hard, fading toward a muted tone where you've eased off.")
    }

    /// The always-visible key for the continuous development ramp.
    /// Five semantic labels make it glanceable without presenting a
    /// noisy percentage as physiological precision.
    var figureCaption: some View {
        developmentLegend
    }

    /// The readiness section: how ready you are to train again, drawn
    /// rather than spoken — the labelled seven-day activity strip and
    /// the personal load-range gauge, with the verdict as the header's
    /// trailing note. The readiness sentence survives as the card's
    /// VoiceOver label.
    func readinessSection(_ report: TrainingLoadReport, line: ReadinessLine) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "Training Load",
                trailing: ReadinessCard.statusText(for: report),
                trailingIsInProgress: report.verdict == .insufficient
            )
            ReadinessCard(report: report, line: line)
        }
    }

    /// Compact placard; tapping opens the evidence and confidence for
    /// each region while keeping confidence out of the colour itself.
    var developmentLegend: some View {
        Button {
            showMuscleMapDetails = true
        } label: {
            VStack(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(MuscleDevelopmentBand.allCases, id: \.rawValue) { band in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(legendColor(for: band))
                                .frame(width: 14, height: 14)
                            Text(band.displayName)
                                .font(Typography.metricMicro)
                                .foregroundStyle(Ink.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text("Training development · tap for details")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md)
            .contentChip()
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Training development legend. Tap for muscle details.")
    }

    func legendColor(for band: MuscleDevelopmentBand) -> Color {
        let channels = band == .noData
            ? MuscleMapChannels.noData
            : MuscleMapChannels(intensity: band.representativeIntensity)
        let rgb = MuscleColor.rgb(
            for: channels,
            theme: colorScheme == .dark ? .dark : .light
        )
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    // MARK: - Up next

    /// The schedule-driven recommendation: what's queued for today (one
    /// tap to start) or the next workout the week holds. Hidden entirely
    /// when no template is pinned to a weekday — the pinned START covers
    /// the unplanned case.
    @ViewBuilder
    func upNextView(_ upNext: UpNext, outlook: StrengthOutlookBoard) -> some View {
        switch upNext.kind {
        case let .scheduled(template, more, easeOff):
            upNextSection(template: template, when: "Today", more: more, startable: true, easeOff: easeOff, outlook: outlook)
        case let .rest(_, next, daysUntil, more):
            if let next {
                upNextSection(template: next, when: upNextWhen(daysUntil), more: more, startable: false, easeOff: false, outlook: outlook)
            }
        case .unscheduled:
            EmptyView()
        }
    }

    /// Rich preview card for the next scheduled workout. The card is
    /// deliberately quiet: hierarchy comes from type, whitespace, a
    /// compact muscle summary, and numbered exercise rows rather than
    /// rules or decorative bars. Today's one-tap Start sits outside
    /// the content surface so the preview and its action remain two
    /// distinct objects.
    func upNextSection(
        template: WorkoutTemplate,
        when: String,
        more: Int,
        startable: Bool,
        easeOff: Bool,
        outlook: StrengthOutlookBoard
    ) -> some View {
        let exercises = template.orderedExercises
        let maxPreview = 5
        let preview = Array(exercises.prefix(maxPreview))
        let remaining = exercises.count - maxPreview
        return VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Up next", trailing: when)

            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(template.name)
                        .font(Typography.display)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(upNextMeta(template, more: more))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(upNextMuscleSummary(template))
                        .panelLegend()
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .background(Surface.cardTintBright, in: Capsule())
                }

                VStack(spacing: Space.md) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { index, exercise in
                        upNextExerciseRow(exercise, index: index + 1)
                    }
                    if remaining > 0 {
                        Text("+\(remaining) more")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 36)
                    }
                }

                if let prLine = prProximityLine(for: template, in: outlook) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "trophy.fill")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.primary)
                        Text(prLine)
                            .font(Typography.caption)
                            .foregroundStyle(Tint.primary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityLabel(prLine)
                }

                if easeOff {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.primary)
                            .accessibilityHidden(true)
                        Text("High load, keep this session lighter")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.primary.opacity(0.9))
                    }
                    .accessibilityLabel("High training load, keep this session lighter")
                }
            }
            .padding(Space.lg)
            .contentCard(bright: true)

            if startable {
                upNextStartButton(template: template)
            }
        }
    }

    /// Meta line under the template name: exercise count and a rough
    /// duration estimate, plus how many other workouts share the day.
    func upNextMeta(_ template: WorkoutTemplate, more: Int) -> String {
        let count = template.orderedExercises.count
        var parts = ["\(count) \(count == 1 ? "exercise" : "exercises")"]
        if let estimate = upNextDurationEstimate(template) {
            parts.append(estimate)
        }
        let base = parts.joined(separator: "  ·  ")
        return more > 0 ? "\(base)  ·  +\(more) more" : base
    }

    /// Rough session length from the plan: work + rest per set, using
    /// the user's default rest, rounded to a 5-minute grain so it
    /// reads as an estimate rather than a promise.
    func upNextDurationEstimate(_ template: WorkoutTemplate) -> String? {
        let sets = template.totalPlannedSets
        guard sets > 0 else { return nil }
        let storedRest = UserDefaults.standard.integer(forKey: SettingsKey.defaultRestSeconds)
        let rest = storedRest > 0 ? storedRest : SettingsDefaults.defaultRestSeconds
        let workSecondsPerSet = 45.0
        let total = Double(sets) * (Double(rest) + workSecondsPerSet)
        let minutes = max(5, Int((total / 60 / 5).rounded()) * 5)
        return "~\(minutes) min"
    }

    /// Compact text summary of planned sets by muscle group.
    func upNextMuscleSummary(_ template: WorkoutTemplate) -> String {
        var counts: [MuscleGroup: Int] = [:]
        var order: [MuscleGroup] = []
        for exercise in template.orderedExercises {
            if counts[exercise.group] == nil { order.append(exercise.group) }
            counts[exercise.group, default: 0] += exercise.effectiveSetCount
        }
        return order
            .map { group in
                let sets = counts[group] ?? 0
                return "\(group.displayName) · \(sets) \(sets == 1 ? "set" : "sets")"
            }
            .joined(separator: "   ")
    }

    /// One exercise in the Up Next preview. A quiet numbered marker
    /// gives the list visual rhythm without separators or set bars.
    func upNextExerciseRow(_ exercise: TemplateExercise, index: Int) -> some View {
        let scheme = upNextScheme(exercise)
        return HStack(alignment: .center, spacing: Space.sm) {
            Text("\(index)")
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.secondary)
                .frame(width: 24, height: 24)
                .background(Surface.cardTintBright, in: Circle())

            Text(exercise.name)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: Space.sm)

            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(scheme.count)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                if let load = scheme.load {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(load)
                            .font(Typography.metricInline)
                            .foregroundStyle(Ink.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let loadUnit = scheme.loadUnit {
                            Text(loadUnit)
                                .font(Typography.metricMicro)
                                .foregroundStyle(Ink.tertiary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.name), \(upNextSchemeAccessibility(scheme))")
    }

    /// The scheme readout, split into typographic parts so the row
    /// can weight them separately: a dim count token ("3 × 12") and
    /// a louder load token ("37.5" + unit). Numerals do the work.
    struct UpNextScheme {
        let count: String
        var load: String? = nil
        var loadUnit: String? = nil
    }

    func upNextScheme(_ exercise: TemplateExercise) -> UpNextScheme {
        switch exercise.trackingMode {
        case .reps:
            if exercise.hasPerSetData {
                let sets = exercise.orderedSets
                let reps = sets.map(\.reps)
                let weights = sets.map(\.weight)
                guard let loW = weights.min(), let hiW = weights.max(),
                      let loR = reps.min(), let hiR = reps.max() else {
                    return UpNextScheme(count: "\(sets.count) sets")
                }
                let count = loR == hiR ? "\(sets.count) × \(loR)" : "\(sets.count) × \(loR)–\(hiR)"
                if loW == hiW {
                    return schemeWithLoad(
                        count: count,
                        weight: loW,
                        loadMode: exercise.loadMode
                    )
                }
                return UpNextScheme(
                    count: count,
                    load: exercise.loadMode.summaryLoadRangeLabel(loW, hiW, unit: unit)
                )
            }
            return schemeWithLoad(
                count: "\(exercise.plannedSets) × \(exercise.plannedReps)",
                weight: exercise.plannedWeight,
                loadMode: exercise.loadMode
            )

        case .duration:
            if exercise.hasPerSetData {
                let sets = exercise.orderedSets
                let durations = sets.map(\.duration)
                guard let lo = durations.min(), let hi = durations.max() else {
                    return UpNextScheme(count: "\(sets.count) sets")
                }
                let duration = lo == hi
                    ? DurationFormatter.string(lo)
                    : "\(DurationFormatter.string(lo))–\(DurationFormatter.string(hi))"
                return durationScheme(
                    count: "\(sets.count) ×",
                    duration: duration,
                    modality: exercise.modality,
                    loadMode: exercise.loadMode,
                    weights: sets.map(\.weight)
                )
            }
            return durationScheme(
                count: "\(exercise.plannedSets) ×",
                duration: DurationFormatter.string(exercise.plannedDuration),
                modality: exercise.modality,
                loadMode: exercise.loadMode,
                weights: [exercise.plannedWeight]
            )
        }
    }

    /// Raw planned load with its actual meaning: bodyweight, added load,
    /// assistance, and resistance never collapse into an ordinary weight.
    private func schemeWithLoad(
        count: String,
        weight: Double,
        loadMode: ExerciseLoadMode
    ) -> UpNextScheme {
        return UpNextScheme(
            count: count,
            load: loadMode.summaryLoadLabel(weight, unit: unit)
        )
    }

    private func durationScheme(
        count: String,
        duration: String,
        modality: ExerciseModality,
        loadMode: ExerciseLoadMode,
        weights: [Double]
    ) -> UpNextScheme {
        let load: String?
        if let lower = weights.min(), let upper = weights.max() {
            load = lower == upper
                ? loadMode.summaryLoadLabel(lower, unit: unit)
                : loadMode.summaryLoadRangeLabel(lower, upper, unit: unit)
        } else {
            load = nil
        }
        let details = ([modality.durationLabelLowercased] + (load.map { ["·", $0] } ?? []))
            .joined(separator: " ")
        return UpNextScheme(count: count, load: duration, loadUnit: details)
    }

    func upNextSchemeAccessibility(_ scheme: UpNextScheme) -> String {
        var parts = [scheme.count]
        if let load = scheme.load { parts.append(load) }
        if let loadUnit = scheme.loadUnit { parts.append(loadUnit) }
        return parts.joined(separator: " ")
    }

    /// Card-specific one-tap start. It floats beside the card rather
    /// than becoming part of the content surface.
    func upNextStartButton(template: WorkoutTemplate) -> some View {
        Button {
            Haptics.crescendo()
            appState.workout.startWorkoutFromTemplate(template)
        } label: {
            HStack(spacing: Space.md) {
                Text("Start this workout")
                    .font(Typography.headline)
                    .foregroundStyle(Tint.primary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Tint.primary)
                    .accessibilityHidden(true)
            }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.xl)
                .frame(minHeight: 50)
                .coloredGlassControl(cornerRadius: Radius.pill)
        }
        .buttonStyle(.plain)
        .softElevation(radius: 14, y: 7, opacity: 0.35)
        .accessibilityLabel("Start \(template.name)")
        .accessibilityHint("Scheduled for today")
    }

    func upNextWhen(_ daysUntil: Int) -> String {
        switch daysUntil {
        case 0:  return "Today"
        case 1:  return "Tomorrow"
        default: return "in \(daysUntil) days"
        }
    }

    /// "4 lb from a Bench Press PR" — the weight-gap framing of the
    /// nearest projected PR, surfaced on the Up Next card only when
    /// that lift is actually in the queued workout (so the nudge is
    /// contextual to what you're about to do, not a dashboard stat).
    /// Returns nil when there's no climbing lift with a real gap, when
    /// the headline lift is a fresh PR (no gap — celebrated elsewhere),
    /// or when the near-PR lift isn't in this template.
    func prProximityLine(for template: WorkoutTemplate, in board: StrengthOutlookBoard) -> String? {
        guard let pr = board.nearestPR else { return nil }
        guard !pr.isFreshPR else { return nil }
        let gapLb = pr.bestE1RM - pr.currentE1RM
        guard gapLb >= 1 else { return nil }
        let inTemplate = template.orderedExercises.contains {
            ExerciseIdentity.key(
                catalogID: $0.catalogID,
                catalogItemID: $0.catalogItemID,
                name: $0.name,
                performanceSignature: ExercisePerformanceSignature(
                    modality: $0.modality,
                    trackingMode: $0.trackingMode,
                    loadMode: $0.loadMode,
                    bodyweightFraction: $0.bodyweightFraction
                )
            ) == pr.historyKey
        }
        guard inTemplate else { return nil }
        let gap = WeightFormatter.string(gapLb, unit: unit, includeUnit: false)
        return "\(gap) \(unit.symbol) from \(Self.article(for: pr.exercise)) \(pr.exercise) PR"
    }

    /// "a" or "an" for an exercise name, by its first letter. Good
    /// enough for the gym vocabulary (Bench, Squat, Overhead Press,
    /// Incline …); avoids a clashing article in the proximity line.
    static func article(for name: String) -> String {
        guard let first = name.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    /// The figure is the hero, so it takes nearly the whole first
    /// viewport — its rendered scale is proportional to this height
    /// (the SCNView's field of view binds to the taller axis), which
    /// is why an earlier half-height value made the model read small.
    /// START is pinned separately in a native safe-area bar. Because
    /// `safeAreaBar` floats over the scroll view instead of reducing
    /// the hero's initial layout height, the figure subtracts the CTA
    /// clearance explicitly so the legend and next section do not sit
    /// underneath the button. The persistent five-band legend needs a
    /// second small clearance of its own. `heroHeight` is frozen on first layout
    /// (see `body`), so the model holds a constant size as the large
    /// title collapses on scroll rather than rescaling mid-gesture.
    func bodyHeroHeight() -> CGFloat {
        // `heroHeight` is latched from the scroll view's own geometry
        // (see `onGeometryChange` in `body`). Until the first layout
        // pass reports it the figure has no height and simply grows into
        // place — masked by the section's fade-in — so we no longer need
        // a `GeometryReader` wrapper (which was inflating the scroll
        // content past the screen width and shifting every row right).
        let base = heroHeight
        guard base > 0 else { return 0 }
        return max(
            base * Self.minimumHeroFraction,
            base * Self.heroFraction
                - Self.pinnedStartBarClearance
                - Self.developmentLegendClearance
        )
    }

    static let heroFraction: CGFloat = 0.98
    static let minimumHeroFraction: CGFloat = 0.68
    /// Includes the legend itself plus the 24-point increase from the
    /// old 8-point model-to-legend gap to the current 32-point gap.
    static let developmentLegendClearance: CGFloat = 88

    /// Reserve the height occupied by the pinned primary CTA above the
    /// floating tab bar. `safeAreaBar` provides native chrome placement;
    /// this value keeps the hero and scroll content from being legible
    /// underneath it.
    static let pinnedStartBarClearance: CGFloat = 104

    var consistencySection: some View {
        let streak = completedSessions.workoutStreak
        return VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Consistency",
                trailing: streakText(streak)
            )
            StreakCalendar(workoutDates: workoutDates, prDates: prDates, month: Date())
                .padding(Space.xl)
                .contentCard()
            NavigationLink {
                ConsistencyScreen()
            } label: {
                HStack {
                    Text("View detail")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(Ink.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .contentChip()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your consistency details")
        }
    }

    func streakText(_ streak: WorkoutStreak) -> String? {
        guard streak.current > 0 else { return nil }
        return "\(streak.current) \(streak.current == 1 ? "week" : "weeks") in a row"
    }

    /// The primary target: a full-width START, the biggest and first-
    /// thing-you-reach control on the screen (first principles — the
    /// most likely next action is always the largest target). Tapping
    /// raises the StartWorkoutSheet, so this one button covers every
    /// way to begin: Repeat / Fresh / a saved template. A neutral soft
    /// elevation lifts it off the black as the screen's clear anchor.
    var startCTA: some View {
        PrimaryActionButton(title: "Start Workout", icon: "chevron.up", inputLabels: ["Start Workout", "Start", "Begin"]) {
            showStartSheet = true
        }
        .softElevation(radius: 18, y: 10, opacity: 0.45)
        .accessibilityHint("Repeat your last workout, start fresh, or pick a template")
    }

    /// START, pinned to the bottom via iOS 26's native safe-area bar.
    /// No custom black tray — the system owns the bar chrome and the
    /// button keeps the app's Liquid Glass CTA treatment.
    var pinnedStartBar: some View {
        startCTA
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.sm)
            // Scrim: content scrolling beneath the pinned CTA fades
            // into the background instead of reading at full strength
            // through and around the button (section titles used to
            // collide with the verb mid-scroll).
            .background {
                LinearGradient(
                    colors: [
                        Surface.background.opacity(0),
                        Surface.background.opacity(0.9),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
    }

    var lastWorkoutSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let session = completedSessions.first {
                SectionHeader(title: "Last workout", trailing: lastWorkoutMeta(for: session))
                lastWorkoutCard(for: session)
            } else {
                SectionHeader(title: "Last workout")
                Text("Nothing logged yet — your first session lands here.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    func lastWorkoutCard(for session: WorkoutSession) -> some View {
        StatStrip(
            stats: [
                Stat(value: "\(Int(session.duration / 60))", unit: "min", label: "Time"),
                lastWorkoutVolumeStat(for: session),
                Stat(value: "\(session.totalSets)", label: "Sets"),
            ],
            valueFont: Typography.statValue,
            edgeAligned: true
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.xl)
        .contentCard()
    }

    private func lastWorkoutVolumeStat(for session: WorkoutSession) -> Stat {
        let summary = session.comparableTonnageSummary
        switch summary.availability {
        case .complete:
            return Stat(
                value: volumeLabel(summary.knownSubtotal),
                unit: unit.symbol,
                label: "Volume",
                accent: lastWorkoutHasPR
            )
        case .partial:
            return Stat(
                value: "\(volumeLabel(summary.knownSubtotal))+",
                unit: unit.symbol,
                label: "Known volume"
            )
        case .unavailable:
            return Stat(value: "—", label: "Volume unavailable")
        }
    }

    /// Relative day + time of the last session, surfaced as the dim
    /// trailing note on the section header (mirroring the streak
    /// header's "N this month"). Keeping the date on the title's
    /// baseline removes the separate header row that floated out of
    /// line with the centred stat columns below.
    func lastWorkoutMeta(for session: WorkoutSession) -> String {
        let date = session.completedAt ?? session.startedAt
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(date) {
            day = "Today"
        } else if calendar.isDateInYesterday(date) {
            day = "Yesterday"
        } else {
            day = Self.dayFormatter.string(from: date)
        }
        return day + "  ·  " + Self.timeFormatter.string(from: date)
    }
}
