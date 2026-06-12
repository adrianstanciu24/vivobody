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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Surface.background.ignoresSafeArea()

                // The living atmosphere: an ember field that burns at a
                // temperature set by the streak + recency, so the home
                // screen reads as a powered-on instrument rather than a
                // flat black report. Sits behind the transparent 3D
                // figure, so the glow breathes through and around it.
                // AmbientForge adapts its own compositing per appearance
                // (additive ember on dark, warm amber wash on light).
                // backgroundExtensionEffect mirrors the forge into the
                // safe-area insets so the glow bleeds under the nav bar.
                AmbientForge(warmth: forgeWarmth)
                    .ignoresSafeArea()
                    .backgroundExtensionEffect()

                ScrollView {
                    // The body leads — your trained figure is the hero
                    // and the readout's subject. The readiness line gives
                    // it a voice; then START is the biggest, first-thing-
                    // you-reach target. The calendar and last workout are
                    // the journal you scroll down to once you've decided.
                    //
                    // The development model is replayed ONCE per render
                    // and every consumer (figure, readiness words, the
                    // drill-down boards) derives from this single state.
                    let modelState = MuscleDevelopment.simulate(from: completedSessions)
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
                            developmentLegend
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
                        readinessReadout(state: modelState).settleIn(1)
                        streakSection.settleIn(2)
                        SectionDivider().settleIn(3)
                        lastWorkoutSection.settleIn(4)
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.xs)
                    .padding(.bottom, Space.xxl)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                // START is pinned, never part of the scroll, so the body
                // hero is free to dominate the first screen while the
                // primary action stays reachable at all times.
                .safeAreaInset(edge: .bottom, spacing: 0) { pinnedStartBar }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    /// the muscles you've trained (development, with a pulse where
    /// you've tightened up), so it reads as your body, not a mannequin.
    private func bodyModelHero(height: CGFloat, state: MuscleDevelopment.State) -> some View {
        RotatableBodyModel(
            renderHeight: height,
            channels: state.nodeChannels
        )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, -Space.gutter)
            .accessibilityElement()
            .accessibilityLabel("Your body, coloured by how developed each muscle is — a vivid orange where you've trained hard, fading toward a muted tone where you've eased off. A slow pulse marks your tightest muscle — the first one to stretch.")
    }

    /// The figure's placard. The body's dominant colour is the
    /// development channel of `MuscleDevelopment` — how built each
    /// muscle is over months, not a one-session pump — so at rest the
    /// hero needs one line naming exactly that, or the glow reads as
    /// decoration. Placed directly beneath the figure (over the plain
    /// background, not overlaid on the model — the muscle/skeleton
    /// detail made an overlaid caption unreadable) so it reads as a
    /// caption under the portrait. The acute "what to train next" voice
    /// is a separate section (`readinessReadout`) you scroll to; this
    /// only decodes the colours you're looking at.
    private var developmentLegend: some View {
        Text("Each muscle wears a more vivid orange the more developed it is, fading toward a muted tone as you ease off. A slow pulse marks your tightest muscle — the first one to stretch.")
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.xl)
            .accessibilityHidden(true)
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

    /// The body's voice: one glanceable line naming what you worked
    /// recently (still glowing on the figure) and what's recovered and
    /// ready to load again — read from the same development model that
    /// colours the figure, so the words and the body always agree. The
    /// per-muscle drill-down stays one tap away.
    @ViewBuilder
    private func readinessReadout(state: MuscleDevelopment.State) -> some View {
        let readiness = state.bodyReadiness()
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Your body", trailing: "right now")
            Text(readinessSentence(readiness))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
            if let tightLine = tightnessSentence(readiness) {
                Text(tightLine)
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !completedSessions.isEmpty {
                allMusclesLink(stats: completedSessions.muscleVolume(), state: state)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A second body-state line, shown only when something has
    /// tightened: names the tight groups (the cool-rimmed muscles on
    /// the figure) and nudges toward mobility. `nil` when nothing is
    /// tight, so the readout stays a single line on a loose body.
    private func tightnessSentence(_ r: BodyReadiness) -> AttributedString? {
        let tight = r.tight.map { $0.group.displayName }
        guard !tight.isEmpty else { return nil }
        return names(tight, color: Ink.primary)
            + run(tight.count == 1 ? " has tightened up" : " have tightened up", color: Ink.secondary)
            + run(" — some mobility would help.", color: Ink.secondary)
    }

    /// The native drill-down — pushes the full per-muscle breakdown
    /// (the same reference screen the Insights "Show all muscles" link
    /// opens) onto Today's own navigation stack. The boards are
    /// derived inside the destination closure — from the same state
    /// the figure renders — so the detraining march runs only when
    /// the detail is actually opened, not on every Today render.
    private func allMusclesLink(stats: [MuscleVolumeStat], state: MuscleDevelopment.State) -> some View {
        NavigationLink {
            MuscleDetailScreen(
                stats: stats,
                momentum: state.muscleMomentum(),
                forecast: state.muscleForecast(),
                tightness: state.muscleTightness()
            )
        } label: {
            HStack(spacing: Space.xs) {
                Text("Show all muscles")
                    .font(Typography.sectionLabel)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Ink.secondary)
        }
        .buttonStyle(.plain)
        .padding(.top, Space.xs)
    }

    /// Two-tone body-state line. Freshly-worked groups take the ember
    /// accent — they're the ones glowing on the figure — recovered-
    /// and-ready groups read in bright ink, and the connective words
    /// stay dim, so the eye lands on the muscle names.
    private func readinessSentence(_ r: BodyReadiness) -> AttributedString {
        guard r.hasTrained else {
            return run("Nothing trained yet — your first workout lights up the body.",
                       color: Ink.secondary)
        }
        let fresh = r.fresh.map { $0.group.displayName }
        let ready = r.ready.map { $0.group.displayName }

        switch (fresh.isEmpty, ready.isEmpty) {
        case (false, false):
            // Lead with the opportunity — what's recovered and ready
            // to load — then name what's still lit from recent work
            // (orange, matching the muscles glowing on the figure).
            return names(ready, color: Ink.primary)
                + run(" — recovered and ready to train. ", color: Ink.secondary)
                + names(fresh, color: Tint.primary)
                + run(" still lit from recent work.", color: Ink.secondary)
        case (false, true):
            // Nothing's fully recovered yet — frame it as work banked,
            // not a limitation. These are the muscles glowing now.
            return names(fresh, color: Tint.primary)
                + run(" — freshly worked, ready again soon.", color: Ink.secondary)
        case (true, false):
            return names(ready, color: Ink.primary)
                + run(" — recovered and ready to train.", color: Ink.secondary)
        case (true, true):
            return run("Fully recovered — ready for your next session.", color: Ink.secondary)
        }
    }

    /// A coloured, semibold run of naturally-joined group names.
    private func names(_ groupNames: [String], color: Color) -> AttributedString {
        var a = AttributedString(joinedGroupNames(groupNames))
        a.foregroundColor = color
        a.font = .system(size: 16, weight: .semibold)
        return a
    }

    /// A dim connective run at body size.
    private func run(_ text: String, color: Color) -> AttributedString {
        var a = AttributedString(text)
        a.foregroundColor = color
        a.font = Typography.body
        return a
    }

    /// Join group names into a clause-leading phrase — lower-cased
    /// "a, b and c", first letter capitalised, capped so the line
    /// never wraps past two rows.
    private func joinedGroupNames(_ names: [String], limit: Int = 4) -> String {
        let lowered = names.map { $0.lowercased() }
        let shown = Array(lowered.prefix(limit))
        let extra = lowered.count - shown.count
        var phrase: String
        switch shown.count {
        case 0:  phrase = ""
        case 1:  phrase = shown[0]
        case 2:  phrase = "\(shown[0]) and \(shown[1])"
        default: phrase = shown.dropLast().joined(separator: ", ") + " and " + shown.last!
        }
        if extra > 0 { phrase = shown.joined(separator: ", ") + " and \(extra) more" }
        return phrase.prefix(1).uppercased() + phrase.dropFirst()
    }

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
                font: .system(size: 36, weight: .bold, design: .monospaced),
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
            valueFont: Self.monoStatValue,
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

    private static let monoStatValue = Font.system(size: 28, weight: .bold, design: .monospaced)

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

    /// Forge temperature, from the shared training-warmth signal so
    /// Today burns at the same scale as every other tab.
    private var forgeWarmth: Double {
        completedSessions.forgeWarmth
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

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}
