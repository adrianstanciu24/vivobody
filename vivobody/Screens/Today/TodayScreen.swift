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
            activations: MuscleHeatmap.nodeIntensities(
                from: completedSessions,
                bodyweight: bodyWeights.latest?.weight ?? ExerciseLoad.defaultBodyweight
            )
        )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, -Space.gutter)
            .accessibilityHidden(true)
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
            SectionHeader(title: "Last workout")

            if let session = completedSessions.first {
                lastWorkoutCard(for: session)
            } else {
                Text("Nothing logged yet — your first session lands here.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private func lastWorkoutCard(for session: WorkoutSession) -> some View {
        let date = session.completedAt ?? session.startedAt
        return VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Text(Self.relativeDayFormatter.string(from: date))
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Text(Self.timeFormatter.string(from: date))
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }

            StatStrip(
                stats: [
                    Stat(value: "\(Int(session.duration / 60))", unit: "min", label: "Time"),
                    Stat(value: volumeLabel(session.totalVolume), unit: unit.symbol, label: "Volume"),
                    Stat(value: "\(session.totalSets)", label: "Sets"),
                ],
                valueFont: Self.monoStatValue
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    private static let relativeDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d"
        f.doesRelativeDateFormatting = true
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
