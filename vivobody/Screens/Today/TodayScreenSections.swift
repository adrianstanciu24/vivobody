//
//  TodayScreenSections.swift
//  vivobody
//
//  Section view builders extracted from TodayScreen: the
//  body-model hero + caption, the Up Next recommendation card,
//  and the Needs-attention / consistency / last-workout journal
//  sections.
//

import SwiftUI
import SwiftData

extension TodayScreen {
    // MARK: - Sections

    /// Anatomical body model — the screen's hero and the subject of
    /// the readiness line beneath it. Edge-to-edge; drag horizontally
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

    /// The figure's placard, placed directly beneath the portrait (over
    /// the plain background, not overlaid — the muscle/skeleton detail
    /// made an overlaid caption unreadable). Once anything is logged the
    /// readiness line gives the body a voice ("Fresh and in the zone");
    /// at cold start, when the untrained figure is uniform, the legend
    /// decodes what the colours will mean instead.
    @ViewBuilder
    var figureCaption: some View {
        if let line = completedSessions.readiness() {
            readinessLine(line)
        } else {
            developmentLegend
        }
    }

    /// The body's voice: one short verdict on how ready you are to train
    /// again, from freshness + the acute:chronic load trend. The lead
    /// clause is brightened against the dimmer nudge; the colour stays
    /// in the figure, so the words read calm and grayscale.
    func readinessLine(_ line: ReadinessLine) -> some View {
        var lead = AttributedString(line.tail.isEmpty ? line.lead : line.lead + " ")
        lead.foregroundColor = Ink.primary
        var tail = AttributedString(line.tail)
        tail.foregroundColor = Ink.secondary

        return Text(lead + tail)
            .font(Typography.body)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            .contentChip()
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel(line.phrase)
    }

    /// The cold-start placard: with no history the figure is uniform, so
    /// this names what the colours will come to mean as you train.
    var developmentLegend: some View {
        Text("Each muscle wears a more vivid orange the more developed it is, fading toward a muted tone as you ease off.")
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            .contentChip()
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
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

    /// Rich preview card for the next scheduled workout: template
    /// name, muscle-group subtitle, a capped exercise list with
    /// set/rep/load schemes, an optional ease-off warning, and a
    /// start button at the bottom. When the workout is today the
    /// card wears the accent tint and the button is live; future
    /// days read as a neutral preview with a disabled button.
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

            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(template.name)
                        .font(Typography.display)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(upNextSubtitle(template, more: more))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(spacing: 0) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { index, exercise in
                        upNextExerciseRow(exercise)
                        if index < preview.count - 1 || remaining > 0 {
                            Rectangle()
                                .fill(Surface.edge)
                                .frame(height: 0.5)
                        }
                    }
                    if remaining > 0 {
                        Text("+\(remaining) more")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Space.sm)
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
                        Image(systemName: "flame")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.primary)
                            .accessibilityHidden(true)
                        Text("Running hot, ease off")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.primary.opacity(0.9))
                    }
                    .accessibilityLabel("Running hot, ease off")
                }

                Rectangle()
                    .fill(Surface.edge)
                    .frame(height: 0.5)

                upNextStartButton(template: template, startable: startable)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.lg)
            .contentCard(tint: startable ? Tint.primary : nil)
        }
    }

    /// One exercise in the Up Next preview: name on the left,
    /// set/rep/load scheme on the right. Compact, non-interactive.
    func upNextExerciseRow(_ exercise: TemplateExercise) -> some View {
        HStack(spacing: Space.sm) {
            Text(exercise.name)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Space.sm)
            Text(exerciseScheme(exercise))
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
    }

    /// Compact set/rep/load summary for one template exercise,
    /// matching the format used on the Template Detail screen.
    func exerciseScheme(_ exercise: TemplateExercise) -> String {
        switch exercise.trackingMode {
        case .reps:
            if exercise.hasPerSetData {
                let sets = exercise.orderedSets
                let weights = sets.map(\.weight)
                guard let lo = weights.min(), let hi = weights.max() else { return "" }
                if lo == hi, let first = sets.first {
                    return "\(sets.count) × \(first.reps) @ \(WeightFormatter.string(lo, unit: unit))"
                }
                let loStr = WeightFormatter.string(lo, unit: unit, includeUnit: false)
                let hiStr = WeightFormatter.string(hi, unit: unit)
                return "\(sets.count) sets · \(loStr)–\(hiStr)"
            }
            return "\(exercise.plannedSets) × \(exercise.plannedReps) @ \(WeightFormatter.string(exercise.plannedWeight, unit: unit))"

        case .duration:
            if exercise.hasPerSetData {
                let sets = exercise.orderedSets
                let durations = sets.map(\.duration)
                guard let lo = durations.min(), let hi = durations.max() else { return "" }
                if lo == hi {
                    return "\(sets.count) × \(DurationFormatter.string(lo)) hold"
                }
                return "\(sets.count) sets · \(DurationFormatter.string(lo))–\(DurationFormatter.string(hi))"
            }
            let base = "\(exercise.plannedSets) × \(DurationFormatter.string(exercise.plannedDuration)) hold"
            return exercise.plannedWeight > 0
                ? "\(base) @ \(WeightFormatter.string(exercise.plannedWeight, unit: unit))"
                : base
        }
    }

    /// Start button at the bottom of the Up Next card. Solid accent
    /// fill with black text when the workout is startable today; a
    /// neutral surface with dimmed text when it's a future-day
    /// preview.
    func upNextStartButton(template: WorkoutTemplate, startable: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        return Button {
            Haptics.crescendo()
            appState.workout.startWorkoutFromTemplate(template)
        } label: {
            Text("Start")
                .font(Typography.headline)
                .foregroundStyle(startable ? Tint.onAccent : Ink.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background {
                    shape.fill(startable ? Tint.primary : Surface.cardTintBright)
                }
        }
        .disabled(!startable)
        .accessibilityLabel("Start \(template.name)")
        .accessibilityHint(startable ? "Scheduled for today" : "Not available yet")
    }

    func upNextWhen(_ daysUntil: Int) -> String {
        switch daysUntil {
        case 0:  return "Today"
        case 1:  return "Tomorrow"
        default: return "in \(daysUntil) days"
        }
    }

    func upNextSubtitle(_ template: WorkoutTemplate, more: Int) -> String {
        let groups = template.muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
        let base = groups.isEmpty
            ? "\(template.orderedExercises.count) ex · \(template.totalPlannedSets) sets"
            : groups
        return more > 0 ? "\(base)  ·  +\(more) more" : base
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
            $0.name.caseInsensitiveCompare(pr.exercise) == .orderedSame
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

    // MARK: - Needs attention

    /// The two or three muscles most worth training next: previously
    /// trained but now stale lead, then never-trained, capped so the
    /// row stays a glance rather than a guilt-list. Empty (and hidden)
    /// until there's training to judge against.
    func attentionMuscles() -> [MuscleVolumeStat] {
        let neglected = appState.analytics.volume.summary.neglected
        let rested = neglected.filter { $0.daysSinceLastTrained != nil }
        let never = neglected.filter { $0.daysSinceLastTrained == nil }
        return Array((rested + never).prefix(3))
    }

    func needsAttentionSection(_ muscles: [MuscleVolumeStat]) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Needs attention")
            HStack(spacing: Space.sm) {
                ForEach(muscles) { stat in
                    attentionTile(stat)
                }
            }
        }
    }

    /// One neglected muscle as a vertical tile anchored by a recency
    /// ring. The ring fills proportionally to how recently the muscle
    /// was trained (or how close its volume is to the minimum
    /// effective threshold), so an empty ring reads "zero work" at a
    /// glance — no text parsing needed. The muscle name and a short
    /// qualifier sit beneath the ring as detail.
    func attentionTile(_ stat: MuscleVolumeStat) -> some View {
        VStack(spacing: Space.sm) {
            AttentionRing(fraction: attentionRecencyFraction(stat))
            Text(stat.muscle.displayName)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(attentionQualifier(stat))
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
        .contentChip()
        .accessibilityElement(children: .combine)
    }

    /// Recency ring fill fraction (0…1). For untrained muscles the
    /// arc depletes over a 14-day reference — 0 days rest = full,
    /// 14+ days = empty, never-trained = empty. For under-volume
    /// muscles the arc represents how close the weekly effective-set
    /// count is to the muscle's minimum effective volume.
    func attentionRecencyFraction(_ stat: MuscleVolumeStat) -> Double {
        switch stat.zone {
        case .untrained:
            guard let days = stat.daysSinceLastTrained else { return 0 }
            return max(0, 1 - Double(days) / 14)
        default:
            return min(1, stat.effectiveSets / stat.landmark.mev)
        }
    }

    func attentionQualifier(_ stat: MuscleVolumeStat) -> String {
        switch stat.zone {
        case .untrained:
            return stat.daysSinceLastTrained.map { "\($0)d" } ?? "new"
        default:
            return "low"
        }
    }

    /// The figure is the hero, so it takes nearly the whole first
    /// viewport — its rendered scale is proportional to this height
    /// (the SCNView's field of view binds to the taller axis), which
    /// is why an earlier half-height value made the model read small.
    /// START is pinned separately in a native safe-area bar. Because
    /// `safeAreaBar` floats over the scroll view instead of reducing
    /// the hero's initial layout height, the figure subtracts the CTA
    /// clearance explicitly so the caption and next section do not sit
    /// underneath the button. `heroHeight` is frozen on first layout
    /// (see `body`), so the model holds a constant size as the large
    /// title collapses on scroll rather than rescaling mid-gesture.
    func bodyHeroHeight(viewport: CGFloat) -> CGFloat {
        let base = heroHeight > 0 ? heroHeight : viewport
        return max(
            base * Self.minimumHeroFraction,
            base * Self.heroFraction - Self.pinnedStartBarClearance
        )
    }

    static let heroFraction: CGFloat = 0.98
    static let minimumHeroFraction: CGFloat = 0.80

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
                Stat(value: volumeLabel(session.totalVolume), unit: unit.symbol, label: "Volume", accent: lastWorkoutHasPR),
                Stat(value: "\(session.totalSets)", label: "Sets"),
            ],
            valueFont: Typography.statValue,
            edgeAligned: true
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.xl)
        .contentCard()
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
