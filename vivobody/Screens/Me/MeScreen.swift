//
//  MeScreen.swift
//  vivobody
//
//  Personal tab — a personal dashboard. Stacked surfaces:
//    • Your journey — lifetime totals + training age.
//    • Milestones — threshold badges across the lifetime totals.
//    • Personal records — top standing records, full wall on tap.
//    • Consistency — current-month calendar + week streak, full
//      month-paging view on tap.
//    • Body weight — latest entry + sparkline, linking to detail.
//    • This month — the current calendar month's recap.
//
//  Everything past the journey is gated on having completed history,
//  so a brand-new user sees only the journey + body-weight prompts.
//
//  App configuration lives on SettingsScreen, pushed from the gear
//  button in the trailing toolbar slot.
//

import SwiftUI
import SwiftData

struct MeScreen: View {
    @Bindable var appState: AppState

    /// All archived sessions. Drives the stats header — we sum
    /// across the full set rather than relying on cached counters,
    /// so the totals stay correct after any edit/delete in History.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil }
    )
    private var completedSessions: [WorkoutSession]

    /// Body-weight log. Sorted reverse-chronological for the card's
    /// "latest" lookup; the sparkline normalizes order itself.
    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var bodyWeightEntries: [BodyWeightEntry]

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    /// Drives the inline log sheet presented from the empty-state
    /// card. Populated state navigates to detail (which has its own
    /// log sheet) so the same affordance never collides.
    @State private var logTarget: BodyWeightLogTarget? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statsSection
                    .settleIn(0)

                GroupSeparator()
                milestonesSection
                    .settleIn(1)
                GroupSeparator()
                personalRecordsSection
                    .settleIn(2)
                GroupSeparator()
                consistencySection
                    .settleIn(3)
                GroupSeparator()
                bodyWeightSection
                    .settleIn(4)
                GroupSeparator()
                monthlyRecapSection
                    .settleIn(5)
            }
            .padding(.top, Space.sm)
            // Extra tail so the last row clears the floating tab bar
            // at rest instead of peeking out from under it.
            .padding(.bottom, Space.section + Space.md)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .forgeBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(item: $logTarget) { target in
            BodyWeightLogSheet(target: target)
        }
    }

    // MARK: - Body weight

    /// Body-weight section. Empty state shows a single CTA, populated
    /// state shows latest + delta + sparkline as a NavigationLink to
    /// the detail screen. The split keeps logging one tap when you
    /// have no data ("get started"), while populated users live in
    /// the detail screen where the same Log sheet is one tap away.
    @ViewBuilder
    private var bodyWeightSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "Body weight",
                trailing: bodyWeightEntries.isEmpty ? nil : "Tap for detail"
            )

            if bodyWeightEntries.isEmpty {
                bodyWeightEmptyCard
            } else {
                NavigationLink {
                    BodyWeightDetail()
                } label: {
                    bodyWeightPopulatedCard
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Type-forward empty body-weight state: one explanatory line and
    /// a single color-preserving glass action — no ghost preview, no card.
    private var bodyWeightEmptyCard: some View {
        ContentUnavailableView {
            Label("Track your body weight to see how it trends alongside your training.", systemImage: "scalemass")
        } actions: {
            Button {
                Haptics.soft()
                logTarget = .create
            } label: {
                Text("Log weight")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var bodyWeightPopulatedCard: some View {
        // Sparkline series is chronological so the line reads
        // left-to-right as time-forward, matching the detail chart.
        let sparkValues = bodyWeightEntries.chronological.map(\.weight)
        let latest = bodyWeightEntries.latest
        let delta = bodyWeightEntries.latestDelta

        return HStack(alignment: .center, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                    Text(latest.map {
                        WeightFormatter.string($0.weight, unit: weightUnit, fractionDigits: 1, includeUnit: false)
                    } ?? "—")
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                    Text(weightUnit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
                if let delta {
                    bodyWeightDeltaLabel(delta: delta)
                } else if let latest {
                    Text("First entry · \(Self.shortDayFormatter.string(from: latest.date))")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
            }

            Spacer(minLength: Space.sm)

            if sparkValues.count >= 2 {
                MiniChart(values: sparkValues, lineColor: Tint.inProgress, fillColor: Tint.inProgress)
                    .frame(width: 96, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func bodyWeightDeltaLabel(delta: Double) -> some View {
        let isUp = delta > 0
        let deltaText = WeightFormatter.deltaString(delta, unit: weightUnit, fractionDigits: 1)
        return HStack(spacing: Space.xs) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(Typography.micro)
            Text("\(deltaText) since last entry")
                .font(Typography.caption)
        }
        .foregroundStyle(Ink.secondary)
    }

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    // MARK: - Stats

    /// Lifetime totals as an *odometer*: one giant volume numeral is
    /// the whole story, with workouts / sets / PRs trailing as a quiet
    /// single-line spec beneath it — not a second hairline stat strip.
    /// That's deliberate: History and Insights both carry a 3-up strip
    /// (a centered weekly scoreboard, an edge-aligned verdict legend),
    /// so repeating it here made Me read as their wallpaper. Demoting
    /// it to an inline footnote lets the odometer be Me's singular
    /// number, the counterpart to History's this-week *log*. The
    /// accented PR count keeps the achievement identity History lacks.
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Your journey",
                trailing: completedSessions.isEmpty ? nil : "All time"
            )

            if completedSessions.isEmpty {
                emptyJourney
            } else {
                VStack(alignment: .leading, spacing: Space.md) {
                    MetricView(
                        label: "Total volume",
                        value: volumeLabel,
                        unit: weightUnit.symbol,
                        valueFont: Typography.metricHero
                    )
                    lifetimeLine
                    if let ageText = completedSessions.trainingAgeText {
                        Text(ageText)
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Milestones

    /// Lifetime-progress badges in a horizontal rail. Each tile is a
    /// goal you're climbing toward (or a cleared category wearing the
    /// accent) — the achievement layer the odometer only counts.
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Milestones")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(completedSessions.milestones(unit: weightUnit, prCount: personalRecords)) { milestone in
                        MilestoneBadge(milestone: milestone)
                    }
                }
            }
        }
    }

    // MARK: - Personal records

    /// Top standing records as a preview; the full wall is one tap
    /// away via the header. Renders a quiet prompt when the user has
    /// history but no exercise tracked across two sessions yet.
    @ViewBuilder
    private var personalRecordsSection: some View {
        let records = completedSessions.personalRecords
        VStack(alignment: .leading, spacing: Space.md) {
            if records.isEmpty {
                SectionHeader(title: "Personal records")
                Text("Log a lift across two or more sessions to set your first record.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            } else {
                NavigationLink {
                    PersonalRecordsScreen()
                } label: {
                    SectionHeader(
                        title: "Personal records",
                        trailing: records.count > 3 ? "See all" : nil
                    )
                }
                .buttonStyle(.plain)

                VStack(spacing: Space.sm) {
                    ForEach(Array(records.prefix(3))) { record in
                        PRRow(record: record, unit: weightUnit)
                    }
                }
            }
        }
    }

    // MARK: - Consistency

    /// Current-month calendar + week-streak note, tapping through to
    /// the full month-paging Consistency screen.
    private var consistencySection: some View {
        let streak = completedSessions.workoutStreak
        return VStack(alignment: .leading, spacing: Space.md) {
            NavigationLink {
                ConsistencyScreen()
            } label: {
                SectionHeader(title: "Consistency", trailing: streakText(streak))
            }
            .buttonStyle(.plain)

            NavigationLink {
                ConsistencyScreen()
            } label: {
                StreakCalendar(workoutDates: workoutDates, month: Date())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Space.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if workoutDates.isEmpty {
                Text("Your training days light up here as you log workouts.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private func streakText(_ streak: WorkoutStreak) -> String? {
        guard streak.current > 0 else { return nil }
        return "\(streak.current) \(streak.current == 1 ? "week" : "weeks") in a row"
    }

    // MARK: - This month

    private var monthlyRecapSection: some View {
        let recap = completedSessions.monthlyRecap
        return VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "This month", trailing: recap.monthLabel)
            StatStrip(stats: [
                Stat(value: "\(recap.workouts)", label: recap.workouts == 1 ? "workout" : "workouts"),
                Stat(value: WeightFormatter.volumeValue(recap.volume, unit: weightUnit), unit: weightUnit.symbol, label: "volume"),
                Stat(value: "\(recap.prs)", label: recap.prs == 1 ? "PR" : "PRs", accent: recap.prs > 0),
            ])
            .padding(Space.xl)
            .contentCard()
        }
    }

    /// Workout days as start-of-day instants for the calendar.
    private var workoutDates: Set<Date> {
        let cal = Calendar.current
        return Set(completedSessions.compactMap { session in
            session.completedAt.map { cal.startOfDay(for: $0) }
        })
    }

    /// The odometer's spec line: lifetime workouts · sets · PRs on one
    /// quiet row. Values lead in white, labels trail dim, separators
    /// recede — structurally distinct from the boxed 3-up strips on
    /// History and Insights, so the giant volume numeral keeps the
    /// spotlight. The PR count alone wears the accent.
    private var lifetimeLine: some View {
        Text(lifetimeSummary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel("\(totalWorkouts) workouts, \(totalSets) sets, \(personalRecords) personal records all time")
    }

    private var lifetimeSummary: AttributedString {
        let parts: [(value: String, label: String, accent: Bool)] = [
            ("\(totalWorkouts)", totalWorkouts == 1 ? "workout" : "workouts", false),
            ("\(totalSets)", totalSets == 1 ? "set" : "sets", false),
            ("\(personalRecords)", personalRecords == 1 ? "PR" : "PRs", personalRecords > 0),
        ]
        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 {
                var separator = AttributedString("   ·   ")
                separator.foregroundColor = Ink.quaternary
                result += separator
            }
            var value = AttributedString(part.value)
            value.font = Typography.sectionHeading
            value.foregroundColor = part.accent ? Tint.primary : Ink.primary
            result += value

            var label = AttributedString(" " + part.label)
            label.font = Typography.body
            label.foregroundColor = Ink.tertiary
            result += label
        }
        return result
    }

    /// Type-forward empty journey — a quiet heading and one line, no
    /// ghost tiles.
    private var emptyJourney: some View {
        ContentUnavailableView(
            "Log your first workout",
            systemImage: "flame",
            description: Text("Your lifetime volume, workouts, and sets will land here.")
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Derived

    private var totalWorkouts: Int { completedSessions.count }

    private var totalSets: Int {
        completedSessions.reduce(0) { $0 + $1.totalSets }
    }

    /// Count of personal records the user currently holds — one per
    /// tracked lift across the archive (each exercise's all-time best
    /// is, by definition, a PR you hold). Drives the accented PR
    /// numeral in the lifetime odometer.
    private var personalRecords: Int {
        completedSessions.progressByExercise.count
    }

    private var totalVolume: Double {
        completedSessions.reduce(0) { $0 + $1.totalVolume }
    }

    /// Volume label tuned for the lifetime totals card. The
    /// formatter handles the < 10k vs ≥ 10k branching (full-grouped
    /// vs compact "k") AND unit conversion in one call.
    private var volumeLabel: String {
        WeightFormatter.volumeValue(totalVolume, unit: weightUnit)
    }
}

#Preview {
    NavigationStack {
        MeScreen(appState: AppState())
            .navigationTitle("Me")
    }
    .preferredColorScheme(.dark)
}
