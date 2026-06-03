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

    /// Body-weight log — the latest entry sets the load for unloaded
    /// movements in the muscle heatmap (push-ups, pull-ups, planks).
    @Query private var bodyWeights: [BodyWeightEntry]

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
            ScrollView {
                // Order is deliberate: the workout you can start is at the
                // top, thumb-reachable, above the fold — "Today is the
                // workout queued up, one tap from starting." The calendar
                // and history are the journal underneath, reached by a
                // scroll once you've decided.
                VStack(alignment: .leading, spacing: Space.section) {
                    bodyModelHero(height: heroHeight > 0 ? heroHeight : proxy.size.height)
                    muscleBalanceReadout
                    streakSection
                    SectionDivider()
                    lastWorkoutSection
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.xs)
                // Clear the floating "+" FAB (56pt) so the last
                // section can always scroll above it.
                .padding(.bottom, 72)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                // Freeze the first valid viewport height; ignore every
                // change that follows as the tab bar minimizes on scroll
                // (which grows the viewport and would otherwise re-scale
                // the model). Reading the tracked view's own geometry —
                // not a captured outer proxy — is what makes SwiftUI
                // actually deliver these updates. Measured BEFORE the
                // bottom inset below so the floating "+" never steals
                // height from the hero (which shrank the figure).
                if heroHeight == 0, newHeight > 0 { heroHeight = newHeight }
            }
            // Floating "+" FAB. An overlay rather than a safeAreaInset
            // so it doesn't reserve scroll height (which would shrink
            // the model); offset up past the tab bar's safe area.
            .overlay(alignment: .bottomLeading) {
                startButton
                    .padding(.leading, Space.gutter)
                    .padding(.bottom, Space.lg)
            }
        }
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $showStartSheet, onDismiss: runPendingStart) {
            StartWorkoutSheet(
                lastSession: completedSessions.first,
                templates: sortedTemplates,
                onSelect: queueStart
            )
        }
    }

    // MARK: - Sections

    /// Anatomical body model, full-screen and edge-to-edge atop the
    /// screen. Drag horizontally to rotate; vertical drags fall
    /// through to the scroll. Purely decorative for now — the Start
    /// CTA sits below it, one short scroll away.
    private func bodyModelHero(height: CGFloat) -> some View {
        RotatableBodyModel(
            renderHeight: height,
            channels: MuscleDevelopment.nodeChannels(
                from: completedSessions,
                bodyweight: bodyWeights.latest?.weight ?? ExerciseLoad.defaultBodyweight
            )
        )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, -Space.gutter)
            .accessibilityHidden(true)
    }

    /// The "right now" companion to the 3D figure: a quiet, glanceable
    /// readout of how this week's effective sets spread across the
    /// muscles, and the one most worth training next. Type-forward and
    /// non-interactive — the deeper analysis lives on the Insights tab.
    @ViewBuilder
    private var muscleBalanceReadout: some View {
        if !completedSessions.isEmpty {
            let stats = completedSessions.muscleVolume()
            let summary = stats.summary
            VStack(alignment: .leading, spacing: Space.lg) {
                SectionHeader(title: "Muscle balance", trailing: "last 7 days")
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(balanceSummaryAttributed(summary))
                        .font(Typography.body)
                        .fixedSize(horizontal: false, vertical: true)
                    trainNextLine(summary)
                }
                allMusclesLink(stats: stats)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The native drill-down — pushes the full per-muscle breakdown
    /// (the same reference screen the Insights "Show all muscles" link
    /// opens) onto Today's own navigation stack. Momentum and forecast
    /// are derived inside the destination closure so the detraining
    /// simulation runs only when the detail is actually opened, not on
    /// every Today render.
    private func allMusclesLink(stats: [MuscleVolumeStat]) -> some View {
        NavigationLink {
            let bodyweight = bodyWeights.latest?.weight ?? ExerciseLoad.defaultBodyweight
            MuscleDetailScreen(
                stats: stats,
                momentum: completedSessions.muscleMomentum(bodyweight: bodyweight),
                forecast: completedSessions.muscleForecast(bodyweight: bodyweight)
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

    /// The zone split as one type-forward line: each count brightened
    /// against dim words, the in-range tally in the accent so the
    /// healthy number is the one that catches the eye.
    private func balanceSummaryAttributed(_ summary: MuscleVolumeSummary) -> AttributedString {
        func count(_ n: Int, _ color: Color) -> AttributedString {
            var s = AttributedString("\(n)")
            s.foregroundColor = color
            s.font = .system(size: 16, weight: .semibold)
            return s
        }
        func word(_ text: String) -> AttributedString {
            var s = AttributedString(text)
            s.foregroundColor = Ink.tertiary
            return s
        }
        let separator = word("   ·   ")
        return count(summary.optimalCount, Tint.primary) + word(" in range")
            + separator + count(summary.underCount, Ink.primary) + word(" to build")
            + separator + count(summary.restingCount, Ink.primary) + word(" resting")
    }

    /// One line naming the muscle most worth the next session, or an
    /// affirmation when everything trained is in range.
    @ViewBuilder
    private func trainNextLine(_ summary: MuscleVolumeSummary) -> some View {
        if let next = summary.neglected.first {
            Text(trainNextAttributed(next.muscle.displayName))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Every muscle you've trained is in its productive range.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone "Train next: <muscle>" — the muscle name brightened
    /// against the dimmer lead (AttributedString; `Text` `+` is
    /// deprecated).
    private func trainNextAttributed(_ name: String) -> AttributedString {
        var lead = AttributedString("Train next: ")
        lead.foregroundColor = Ink.secondary
        var muscle = AttributedString(name)
        muscle.foregroundColor = Ink.primary
        return lead + muscle
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
            Text("\(currentStreakDays)")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(currentStreakDays > 0 ? Tint.inProgress : Ink.primary)
                .monospacedDigit()
            Text(currentStreakDays == 1 ? "day" : "days")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
        }
    }

    /// Floating lime "+" FAB — the single entry point to starting a
    /// workout. Bottom-left so the 3D model owns the whole hero;
    /// tapping it raises the StartWorkoutSheet (Repeat / Fresh /
    /// templates). Shaped as a capsule (echoing the selected tab
    /// pill) with a top specular sheen + soft elevation so it reads
    /// as a raised piece of material rather than a flat disc.
    private var startButton: some View {
        Button {
            Haptics.soft()
            showStartSheet = true
        } label: {
            plusGlyph
                .frame(width: 78, height: 52)
                .background(Capsule(style: .continuous).fill(Tint.primary))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                }
                .topSpecularSheen(cornerRadius: 26, intensity: 0.22, height: 0.55)
                .softElevation(radius: 16, y: 8, opacity: 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a workout")
    }

    /// A "+" built from two rounded bars rather than the SF Symbol —
    /// thinner strokes with fully rounded caps read crisper and more
    /// modern than the heavy system glyph.
    private var plusGlyph: some View {
        ZStack {
            Capsule().frame(width: 20, height: 4)
            Capsule().frame(width: 4, height: 20)
        }
        .foregroundStyle(Tint.onAccent)
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
