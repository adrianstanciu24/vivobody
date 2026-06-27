//
//  TodayScreen.swift
//  vivobody
//
//  The app's home tab. Quiet, scannable, anchored by the big
//  "Start Workout" call-to-action. Composes three previously-built
//  atoms into their first real screen home:
//    • StreakCalendar — the current month with workout dots
//    • PrimaryActionButton — the START WORKOUT call-to-action
//    • DigitTicker — used inside the LastWorkout stats strip
//
//  The screen reads AppState directly (workout dates, streak count,
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
                            upNextView(upNext).settleIn(3)
                            SectionDivider().settleIn(4)
                        }
                        streakSection.settleIn(5)
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
                // START is pinned, never part of the scroll, so the body
                // hero is free to dominate the first screen while the
                // primary action stays reachable at all times.
                .safeAreaInset(edge: .bottom, spacing: 0) { pinnedStartBar }
                // The living atmosphere shared with every sibling tab: an
                // ember field burning at a temperature set by streak +
                // recency, so home reads as a powered-on instrument rather
                // than a flat black report. Today burns at full intensity
                // (vs the 0.9 the text-dense tabs default to) because the
                // transparent 3D figure sits on top — the glow breathes
                // through and around it. `forgeBackground` also mirrors the
                // ember under the nav/tab bars so it never hard-edges.
                .forgeBackground(intensity: 1.0)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                    // Latch onto the LARGEST viewport height ever seen, not
                    // the first. The pinned-START `safeAreaInset` makes the
                    // container report a transient, collapsed height during
                    // launch layout; freezing that first value shrank the
                    // hero to a thumbnail. Tracking the max ignores the
                    // transient (and the on-scroll tab-bar minimize never
                    // shrinks the figure, since the value only grows).
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
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
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
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
            .accessibilityHidden(true)
    }

    // MARK: - Up next

    /// The schedule-driven recommendation: what's queued for today (one
    /// tap to start) or the next workout the week holds. Hidden entirely
    /// when no template is pinned to a weekday — the pinned START covers
    /// the unplanned case.
    @ViewBuilder
    private func upNextView(_ upNext: UpNext) -> some View {
        switch upNext.kind {
        case let .scheduled(template, more, easeOff):
            upNextSection(template: template, when: "Today", more: more, startable: true, easeOff: easeOff)
        case let .rest(_, next, daysUntil, more):
            if let next {
                upNextSection(template: next, when: upNextWhen(daysUntil), more: more, startable: false, easeOff: false)
            }
        case .unscheduled:
            EmptyView()
        }
    }

    /// Card-free instrument section, the same shape as Streak and Last
    /// workout: a header whose dim trailing carries the "when", then the
    /// template name as the weight-bearing line. When it's today the
    /// name row is the tap target and wears the lone accent arrow;
    /// future days read as a quiet preview.
    private func upNextSection(
        template: WorkoutTemplate,
        when: String,
        more: Int,
        startable: Bool,
        easeOff: Bool
    ) -> some View {
        let detail = VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.sm) {
                Text(template.name)
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if startable {
                    Spacer(minLength: Space.sm)
                    Image(systemName: "arrow.right")
                        .font(Typography.title)
                        .foregroundStyle(Tint.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(upNextSubtitle(template, more: more))
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .lineLimit(1)

            if easeOff {
                Text("Running hot, ease off")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.primary.opacity(0.9))
            }
        }

        return VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Up next", trailing: when)

            if startable {
                Button {
                    Haptics.crescendo()
                    appState.startWorkoutFromTemplate(template)
                } label: { detail }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start \(template.name)")
                    .accessibilityHint("Scheduled for today")
            } else {
                detail.accessibilityElement(children: .combine)
            }
        }
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
            VStack(spacing: 0) {
                ForEach(muscles) { attentionRow($0) }
            }
        }
    }

    /// One muscle on the neglect board: its name carries the weight on
    /// the left, the recency/volume verdict sits dim and right-aligned,
    /// rows parted by the same hairline the screen uses between sections.
    private func attentionRow(_ stat: MuscleVolumeStat) -> some View {
        HStack(spacing: Space.sm) {
            Text(stat.muscle.displayName)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
            Spacer(minLength: Space.sm)
            Text(attentionQualifier(stat))
                .sectionLabelStyle(Opacity.soft)
                .monospacedDigit()
        }
        .frame(minHeight: Space.tapMin)
        .accessibilityElement(children: .combine)
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
    /// START is pinned separately (`safeAreaInset`), so the hero no
    /// longer has to leave scroll room for it; the readiness line just
    /// peeks beneath the figure and scrolls up from there. `heroHeight`
    /// is frozen on first layout (see `body`), so the model holds a
    /// constant size as the large title collapses on scroll rather
    /// than rescaling mid-gesture.
    private func bodyHeroHeight(viewport: CGFloat) -> CGFloat {
        let base = heroHeight > 0 ? heroHeight : viewport
        return base * Self.heroFraction
    }

    private static let heroFraction: CGFloat = 0.80

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Streak",
                trailing: workoutDates.isEmpty ? nil : "\(monthCount(in: Date())) this month"
            )
            streakHeading
            StreakCalendar(workoutDates: workoutDates, month: Date())
        }
    }

    private var streakHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // Rolls into place like the workout's odometer instead of
            // blinking in — the streak feels counted, not printed.
            DigitTicker(
                value: Double(currentStreakDays),
                font: Typography.metricLg,
                color: currentStreakDays > 0 ? Tint.inProgress : Ink.primary
            )
            Text(currentStreakDays == 1 ? "day" : "days")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
        }
    }

    /// The primary target: a full-width START, the biggest and first-
    /// thing-you-reach control on the screen (first principles — the
    /// most likely next action is always the largest target). Tapping
    /// raises the StartWorkoutSheet, so this one button covers every
    /// way to begin: Repeat / Fresh / a saved template. A neutral soft
    /// elevation lifts it off the black as the screen's clear anchor.
    private var startCTA: some View {
        PrimaryActionButton(title: "Start Workout", icon: "chevron.up") {
            showStartSheet = true
        }
        .softElevation(radius: 18, y: 10, opacity: 0.45)
        .accessibilityHint("Repeat your last workout, start fresh, or pick a template")
    }

    /// START, pinned to the bottom via `safeAreaInset`. No background
    /// of its own — the system's soft scroll edge effect handles the
    /// content-to-bar fade, so the button floats directly on the forge
    /// instead of sitting in a black tray.
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
                Stat(value: volumeLabel(session.totalVolume), unit: unit.symbol, label: "Volume"),
                Stat(value: "\(session.totalSets)", label: "Sets"),
            ],
            valueFont: Typography.statValue,
            edgeAligned: true
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Consecutive days back from today (or yesterday) with a
    /// completed session. Today is allowed to be missing — the
    /// streak then counts from yesterday so an unworked morning
    /// doesn't visually reset the count.
    private var currentStreakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = workoutDates

        var cursor = today
        if !dates.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while dates.contains(cursor) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    private func monthCount(in date: Date) -> Int {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: date) else { return 0 }
        return workoutDates.filter { $0 >= interval.start && $0 < interval.end }.count
    }

    private func volumeLabel(_ value: Double) -> String {
        WeightFormatter.volumeValue(value, unit: unit)
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

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}
