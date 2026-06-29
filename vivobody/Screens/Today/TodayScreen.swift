//
//  TodayScreen.swift
//  vivobody
//
//  The app's home tab. Quiet, scannable, anchored by the big
//  "Start Workout" call-to-action. Composes previously-built
//  atoms into their first real screen home:
//    • StreakCalendar — the current month with workout dots + PR pulse
//    • PrimaryActionButton — the START WORKOUT call-to-action
//    • DigitTicker — used inside the LastWorkout stats strip
//
//  The screen reads AppState directly (workout dates, PR dates,
//  last completed session) and emits a single intent: start today's
//  workout. The shell handles presentation.
//

import SwiftUI
import SwiftData

struct TodayScreen: View {
    @Bindable var appState: AppState

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// All archived sessions, most-recent first. Drives the streak
    /// calendar, the "X this month" stat, and the "Last Workout"
    /// card. SwiftUI re-renders this screen automatically when a new
    /// session is inserted into the context (i.e. on workout archive).
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    private var completedSessions: [WorkoutSession]

    /// All saved templates. Sorted on-the-fly into a most-recently-
    /// used-first list for the chip strip; the raw @Query order
    /// doesn't matter beyond identity.
    @Query private var templates: [WorkoutTemplate]

    /// Frozen on first layout and never updated afterwards. The
    /// scroll container's height shrinks as the large navigation
    /// title collapses on scroll; binding the SCNView's height to
    /// that live value made the model visibly re-scale ("zoom") mid-
    /// scroll. Capturing the height once decouples the model from the
    /// title animation so it holds a constant size.
    @State private var heroHeight: CGFloat = 0

    /// Whether the start-workout sheet is presented (raised by the
    /// pinned "+ Start" pill).
    @State private var showStartSheet = false

    /// The start action chosen in the sheet, deferred until the sheet
    /// fully dismisses. Running it in the sheet's onDismiss avoids
    /// presenting the focused ActiveWorkoutScreen over a still-
    /// dismissing sheet.
    @State private var pendingStart: (() -> Void)?

    /// Memoises the development-model replay so the full-history
    /// `simulate` runs only when the archived-session set changes, not
    /// on every body evaluation (height latching, the start sheet, a
    /// unit-preference flip all re-run the body otherwise).
    @State private var modelStateCache = BodyModelStateCache()

    var body: some View {
        GeometryReader { proxy in
                ScrollView {
                    // The body leads — your trained figure is the hero
                    // and the readout's subject. The readiness line gives
                    // it a voice; then START is the biggest, first-thing-
                    // you-reach target. The calendar and last workout are
                    // the journal you scroll down to once you've decided.
                    //
                    // The development model is replayed once per data
                    // change (memoised in BodyModelStateCache) and every
                    // consumer (figure, readiness words, the drill-down
                    // boards) derives from this single state.
                    let modelState = modelStateCache.state(for: completedSessions)
                    let upNext = UpNext.compute(templates: templates, sessions: completedSessions)
                    let attention = attentionMuscles()
                    let outlook = completedSessions.strengthOutlook()
                    VStack(alignment: .leading, spacing: Space.section) {
                        // The figure and its caption read as one unit: the
                        // portrait, then the line decoding its colours sitting
                        // just beneath the feet (over the plain background, not
                        // over the model — the muscle detail made an overlaid
                        // caption unreadable).
                        VStack(spacing: Space.sm) {
                            bodyModelHero(
                                height: bodyHeroHeight(viewport: proxy.size.height),
                                state: modelState
                            )
                            figureCaption
                        }
                            // Depth: the figure settles back into the forge as
                            // you scroll past it. Driven by .scrollTransition
                            // (render-thread) rather than a scroll-offset
                            // @State, so it never re-runs the body model's
                            // channel computation per frame — that was what
                            // made scrolling feel like slow motion.
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .scaleEffect(1 - abs(phase.value) * 0.07, anchor: .top)
                                    .opacity(1 - abs(phase.value) * 0.30)
                            }
                            .settleIn(0)
                        if !attention.isEmpty {
                            needsAttentionSection(attention).settleIn(1)
                            SectionDivider().settleIn(2)
                        }
                        if upNext.isPresentable {
                            upNextView(upNext, outlook: outlook).settleIn(3)
                            SectionDivider().settleIn(4)
                        }
                        consistencySection.settleIn(5)
                        SectionDivider().settleIn(6)
                        lastWorkoutSection.settleIn(7)
                    }
                    .padding(.top, Space.xs)
                    .padding(.bottom, Space.xxl)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .safeAreaPadding(.bottom, Self.pinnedStartBarClearance)
                // START is pinned in the native iOS 26 safe-area bar,
                // never part of the scroll. The matching safe-area
                // padding above reserves its occupied height so body
                // copy never sits underneath the CTA or tab chrome.
                .safeAreaBar(edge: .bottom, spacing: 0) { pinnedStartBar }
                // The living atmosphere shared with every sibling tab: an
                // ember field burning at a temperature set by streak +
                // recency, so home reads as a powered-on instrument rather
                // than a flat black report. Dialed below the sibling tabs'
                // 0.9 default because Today's transparent 3D figure leaves
                // the hero halo unobstructed (siblings cover it with dark
                // content), so a matching intensity reads far brighter
                // here; this keeps the forge consistent across tabs.
                // `forgeBackground` also mirrors the ember under the
                // nav/tab bars so it never hard-edges.
                .forgeBackground(intensity: 0.6)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                    // Latch onto the LARGEST viewport height ever seen, not
                    // the first. Native bottom chrome can make the container
                    // report a transient, collapsed height during launch
                    // layout; freezing that first value shrank the hero to a
                    // thumbnail. Tracking the max ignores the transient (and
                    // the on-scroll tab-bar minimize never shrinks the figure,
                    // since the value only grows).
                    if newHeight > heroHeight { heroHeight = newHeight }
                }
        }
        .onAppear {
            Haptics.prepare()
            // A soft "powered-on" tick as the screen settles in — the
            // ambient-confirmation cousin of the workout's haptics.
            Haptics.soft()
        }
        .sheet(isPresented: $showStartSheet, onDismiss: runPendingStart) {
            StartWorkoutSheet(
                lastSession: completedSessions.first,
                templates: sortedTemplates,
                onSelect: queueStart
            )
        }
    }

    // MARK: - Sections

    /// Anatomical body model — the screen's hero and the subject of
    /// the readiness line beneath it. Edge-to-edge; drag horizontally
    /// to rotate, vertical drags fall through to the scroll. Lit by
    /// how developed each muscle is (vivid orange where you've trained
    /// hard, fading toward a muted tone where you've eased off), so it
    /// reads as your body, not a mannequin.
    private func bodyModelHero(height: CGFloat, state: MuscleDevelopment.State) -> some View {
        RotatableBodyModel(
            renderHeight: height,
            channels: state.nodeChannels
        )
            .frame(maxWidth: .infinity)
            .frame(height: height)
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
    private var figureCaption: some View {
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
    private func readinessLine(_ line: ReadinessLine) -> some View {
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
    private var developmentLegend: some View {
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
    private func upNextView(_ upNext: UpNext, outlook: StrengthOutlookBoard) -> some View {
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
    private func upNextSection(
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
    private func upNextExerciseRow(_ exercise: TemplateExercise) -> some View {
        HStack(spacing: Space.sm) {
            Text(exercise.name)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
            Spacer(minLength: Space.sm)
            Text(exerciseScheme(exercise))
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
    }

    /// Compact set/rep/load summary for one template exercise,
    /// matching the format used on the Template Detail screen.
    private func exerciseScheme(_ exercise: TemplateExercise) -> String {
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
    private func upNextStartButton(template: WorkoutTemplate, startable: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        return Button {
            Haptics.crescendo()
            appState.startWorkoutFromTemplate(template)
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

    private func upNextWhen(_ daysUntil: Int) -> String {
        switch daysUntil {
        case 0:  return "Today"
        case 1:  return "Tomorrow"
        default: return "in \(daysUntil) days"
        }
    }

    private func upNextSubtitle(_ template: WorkoutTemplate, more: Int) -> String {
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
    private func prProximityLine(for template: WorkoutTemplate, in board: StrengthOutlookBoard) -> String? {
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
    private static func article(for name: String) -> String {
        guard let first = name.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    // MARK: - Needs attention

    /// The two or three muscles most worth training next: previously
    /// trained but now stale lead, then never-trained, capped so the
    /// row stays a glance rather than a guilt-list. Empty (and hidden)
    /// until there's training to judge against.
    private func attentionMuscles() -> [MuscleVolumeStat] {
        let neglected = completedSessions.muscleVolume().summary.neglected
        let rested = neglected.filter { $0.daysSinceLastTrained != nil }
        let never = neglected.filter { $0.daysSinceLastTrained == nil }
        return Array((rested + never).prefix(3))
    }

    private func needsAttentionSection(_ muscles: [MuscleVolumeStat]) -> some View {
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
    private func attentionTile(_ stat: MuscleVolumeStat) -> some View {
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
    private func attentionRecencyFraction(_ stat: MuscleVolumeStat) -> Double {
        switch stat.zone {
        case .untrained:
            guard let days = stat.daysSinceLastTrained else { return 0 }
            return max(0, 1 - Double(days) / 14)
        default:
            return min(1, stat.effectiveSets / stat.landmark.mev)
        }
    }

    private func attentionQualifier(_ stat: MuscleVolumeStat) -> String {
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
    private func bodyHeroHeight(viewport: CGFloat) -> CGFloat {
        let base = heroHeight > 0 ? heroHeight : viewport
        return max(
            base * Self.minimumHeroFraction,
            base * Self.heroFraction - Self.pinnedStartBarClearance
        )
    }

    private static let heroFraction: CGFloat = 0.80
    private static let minimumHeroFraction: CGFloat = 0.64

    /// Reserve the height occupied by the pinned primary CTA above the
    /// floating tab bar. `safeAreaBar` provides native chrome placement;
    /// this value keeps the hero and scroll content from being legible
    /// underneath it.
    private static let pinnedStartBarClearance: CGFloat = 104

    private var consistencySection: some View {
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

    private func streakText(_ streak: WorkoutStreak) -> String? {
        guard streak.current > 0 else { return nil }
        return "\(streak.current) \(streak.current == 1 ? "week" : "weeks") in a row"
    }

    /// The primary target: a full-width START, the biggest and first-
    /// thing-you-reach control on the screen (first principles — the
    /// most likely next action is always the largest target). Tapping
    /// raises the StartWorkoutSheet, so this one button covers every
    /// way to begin: Repeat / Fresh / a saved template. A neutral soft
    /// elevation lifts it off the black as the screen's clear anchor.
    private var startCTA: some View {
        PrimaryActionButton(title: "Start Workout", icon: "chevron.up", inputLabels: ["Start Workout", "Start", "Begin"]) {
            showStartSheet = true
        }
        .softElevation(radius: 18, y: 10, opacity: 0.45)
        .accessibilityHint("Repeat your last workout, start fresh, or pick a template")
    }

    /// START, pinned to the bottom via iOS 26's native safe-area bar.
    /// No custom black tray — the system owns the bar chrome and the
    /// button keeps the app's Liquid Glass CTA treatment.
    private var pinnedStartBar: some View {
        startCTA
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.sm)
    }

    private var lastWorkoutSection: some View {
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

    private func lastWorkoutCard(for session: WorkoutSession) -> some View {
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
    private func lastWorkoutMeta(for session: WorkoutSession) -> String {
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

    // MARK: - Start intent

    /// Record the chosen start path and let the sheet dismiss. The
    /// work runs in `runPendingStart` once the sheet is gone, so the
    /// focused ActiveWorkoutScreen never presents over a dismissing
    /// sheet.
    private func queueStart(_ intent: StartIntent) {
        switch intent {
        case .repeatLast:
            let last = completedSessions.first
            pendingStart = { appState.startTodaysWorkout(basedOn: last) }
        case .fresh:
            pendingStart = { appState.startTodaysWorkout(basedOn: nil) }
        case .template(let template):
            pendingStart = { appState.startWorkoutFromTemplate(template) }
        }
    }

    private func runPendingStart() {
        let action = pendingStart
        pendingStart = nil
        action?()
    }

    // MARK: - Derived

    /// Templates ordered for the start sheet: most-recently-used
    /// first, then never-used templates in their Library sortOrder.
    /// A `@Query` predicate-based sort can't express this hybrid
    /// (lastUsedAt is optional), so it's resolved client-side.
    private var sortedTemplates: [WorkoutTemplate] {
        templates.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?):       return l > r
            case (.some, .none):     return true
            case (.none, .some):     return false
            case (.none, .none):     return lhs.sortOrder < rhs.sortOrder
            }
        }
    }

    /// Calendar days on which the user has at least one archived
    /// session. Drives the StreakCalendar fills.
    private var workoutDates: Set<Date> {
        Set(completedSessions.map {
            Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt)
        })
    }

    /// Calendar days on which a PR was set. Passed to StreakCalendar
    /// so PR dots can pulsate.
    private var prDates: Set<Date> {
        Set(completedSessions.filter { prSessionIDs.contains($0.id) }
            .map { Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    private func volumeLabel(_ value: Double) -> String {
        WeightFormatter.volumeValue(value, unit: unit)
    }

    /// Whether the most recent session set a new all-time record
    /// on any exercise — the same semantics as History's PR badge and
    /// the live PR-celebration overlay. When true, the Volume stat on
    /// the Last workout strip wears the completion accent.
    private var lastWorkoutHasPR: Bool {
        guard let lastID = completedSessions.first?.id else { return false }
        return prSessionIDs.contains(lastID)
    }

    /// IDs of sessions in which at least one exercise hit a new
    /// all-time record at the moment it was logged. Reps exercises
    /// track top weight; duration exercises track longest hold. Walks
    /// the archive oldest-first by stable exercise identity. Matches
    /// `HistoryScreen.sessionsWithPR` exactly.
    private var prSessionIDs: Set<UUID> {
        var bestByExercise: [String: Double] = [:]
        var prIDs: Set<UUID> = []
        for session in completedSessions.reversed() {
            for exercise in session.orderedExercises {
                let metric = prMetric(for: exercise)
                guard metric > 0 else { continue }
                let key = exercise.historyKey
                if metric > bestByExercise[key, default: 0] {
                    bestByExercise[key] = metric
                    prIDs.insert(session.id)
                }
            }
        }
        return prIDs
    }

    private func prMetric(for exercise: Exercise) -> Double {
        let completed = exercise.sets.filter(\.isCompleted)
        switch exercise.trackingMode {
        case .reps:
            return completed.map(\.weight).max() ?? 0
        case .duration:
            return completed.map(\.duration).max() ?? 0
        }
    }

    // MARK: - Formatters

    /// Weekday + month/day for sessions older than yesterday. Today
    /// and yesterday are resolved by hand in `lastWorkoutMeta` —
    /// `doesRelativeDateFormatting` silently yields an empty string
    /// when paired with a custom `dateFormat`, which is why the date
    /// used to render blank.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE  ·  MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

/// Memoises `MuscleDevelopment.simulate` for `TodayScreen`. The screen
/// body is re-evaluated for many reasons unrelated to training data, so
/// replaying the full O(sessions × muscles) history each time is
/// wasteful. This holds the last result keyed on a cheap signature
/// (session count + latest completion) and replays only when that
/// signature changes. Deliberately NOT `@Observable`: it is a passive
/// cache read during `body`, and the `@Query` feeding it already
/// invalidates the body when the archived-session set changes. Archived
/// sessions are immutable history, so count + latest completion fully
/// identify the input.
private final class BodyModelStateCache {
    private var signature: String?
    private var cached = MuscleDevelopment.State()

    func state(for sessions: [WorkoutSession]) -> MuscleDevelopment.State {
        let signature = Self.signature(for: sessions)
        if signature != self.signature {
            self.signature = signature
            cached = MuscleDevelopment.simulate(from: sessions)
        }
        return cached
    }

    private static func signature(for sessions: [WorkoutSession]) -> String {
        "\(sessions.count)-\(sessions.first?.completedAt?.timeIntervalSince1970 ?? 0)"
    }
}

/// Circular recency ring for one neglected-muscle tile. The arc
/// animates from empty to its fill fraction on appear, so the ring
/// "fills" as the section settles in. Honors Reduce Motion by
/// showing the final value immediately.
private struct AttentionRing: View {
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Surface.edge, lineWidth: 3)
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: shown ? fraction : 0)
                    .stroke(
                        Tint.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 40, height: 40)
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                    shown = true
                }
            }
        }
    }
}

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}
