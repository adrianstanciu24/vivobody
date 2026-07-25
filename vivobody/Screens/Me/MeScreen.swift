//
//  MeScreen.swift
//  vivobody
//
//  Personal tab — a personal dashboard. Stacked surfaces:
//    • Your journey — lifetime totals + training age.
//    • Milestones — threshold badges across the lifetime totals.
//    • Personal records — top standing records, full wall on tap.
//    • Body weight — latest entry + sparkline, linking to detail.
//    • This month — the current calendar month's recap.
//
//  Everything past the journey is gated on having completed history,
//  so a brand-new user sees only the journey + body-weight prompts.
//
//  App configuration lives on SettingsScreen, pushed from the gear
//  button in the trailing toolbar slot.
//

import VivoKit
import SwiftUI
import SwiftData

struct MeScreen: View {
    @Bindable var appState: AppState

    /// One-row probe: does any archived session exist? Drives the
    /// empty-state gates instantly. The stats themselves come from the
    /// shared analytics overview — recomputed on every archive change
    /// (so totals stay correct after any edit/delete in History)
    /// without this screen faulting every exercise and set.
    @Query private var latestSessions: [WorkoutSession]

    private var hasHistory: Bool { latestSessions.first != nil }

    private var overview: ArchiveOverview { appState.analytics.overview }

    init(appState: AppState) {
        self.appState = appState
        var latest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        latest.fetchLimit = 1
        _latestSessions = Query(latest)

        // The card needs only a compact recent sparkline plus the two
        // newest values for its hero and delta, never the full history.
        var recentWeights = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        recentWeights.fetchLimit = 30
        _bodyWeightEntries = Query(recentWeights)
    }

    /// A bounded reverse-chronological window for the card's current
    /// value, delta, and compact recent sparkline.
    @Query
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
            // The overview lands one worker pass after launch; until
            // then a populated archive shows a quiet placeholder
            // instead of momentary zeroed odometers.
            if hasHistory && !appState.analytics.hasCoreReports {
                loadingState
            } else {
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
                    bodyWeightSection
                        .settleIn(3)
                    GroupSeparator()
                    monthlyRecapSection
                        .settleIn(4)
                }
                .padding(.top, Space.sm)
                // Extra tail so the last row clears the floating tab bar
                // at rest instead of peeking out from under it.
                .padding(.bottom, Space.section + Space.md)
            }
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

    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.top, Space.xxl)
            .accessibilityLabel("Loading your training totals")
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
                .accessibilityHint("Opens body weight details")
            }
        }
    }

    /// Quiet inline empty state, matching the Personal-records prompt
    /// one section up: a single caption line and a compact left-aligned
    /// action — no icon, no centered full-screen treatment.
    private var bodyWeightEmptyCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Track your body weight to see how it trends alongside your training.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
            Button {
                Haptics.soft()
                logTarget = .create
            } label: {
                Text("Log weight")
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyWeightPopulatedCard: some View {
        // The query is newest-first; reverse its bounded window once so
        // the sparkline reads left-to-right as time-forward.
        let sparkValues = bodyWeightEntries.reversed().map(\.weight)
        let latest = bodyWeightEntries.first
        let delta = bodyWeightEntries.count >= 2
            ? bodyWeightEntries[0].weight - bodyWeightEntries[1].weight
            : nil

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
                MiniChart(values: sparkValues, lineColor: Tint.inProgress, fillColor: Tint.inProgress, accessibilityLabel: "Body weight trend")
                    .frame(width: 96, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func bodyWeightDeltaLabel(delta: Double) -> some View {
        let isUp = delta > 0
        let deltaText = WeightFormatter.deltaString(delta, unit: weightUnit, fractionDigits: 1)
        return HStack(spacing: Space.xs) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(Typography.micro)
                .accessibilityHidden(true)
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
                trailing: hasHistory ? "All time" : nil
            )

            if !hasHistory {
                emptyJourney
            } else {
                VStack(alignment: .leading, spacing: Space.md) {
                    MetricView(
                        label: lifetimeVolumeLabel,
                        value: volumeLabel,
                        unit: lifetimeVolumeUnit,
                        valueFont: Typography.metricHero
                    )
                    lifetimeLine
                    if let ageText = JourneyFormatting.trainingAgeText(
                        since: overview.trainingSince
                    ) {
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
    /// accent) — the achievement layer the odometer only counts. Tiles
    /// light in sequence (`powerOn`), the rail's lamps warming up.
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Milestones")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    let milestones = JourneyMilestones.build(
                        workouts: overview.totalWorkouts,
                        tonnage: overview.lifetimeTonnage,
                        longestStreak: overview.streak.longest,
                        prCount: personalRecords,
                        unit: weightUnit
                    )
                    // Positional identity: Milestone ids are freshly minted
                    // on every recompute, which would re-fire powerOn.
                    ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                        MilestoneBadge(milestone: milestone)
                            .powerOn(index)
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
        let records = appState.analytics.progress.standingRecords
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
                .accessibilityHint("Opens all personal records")

                VStack(spacing: Space.sm) {
                    ForEach(Array(records.prefix(3))) { record in
                        PRRow(record: record, unit: weightUnit)
                    }
                }
            }
        }
    }

    // MARK: - This month

    private var monthlyRecapSection: some View {
        let recap = overview.monthlyRecap
        return VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "This month", trailing: recap.monthLabel)
            StatStrip(stats: [
                Stat(value: "\(recap.workouts)", label: recap.workouts == 1 ? "workout" : "workouts"),
                monthlyVolumeStat(recap),
                Stat(value: "\(recap.prs)", label: recap.prs == 1 ? "PR" : "PRs", accent: recap.prs > 0),
            ])
            .padding(Space.xl)
            .contentCard()
        }
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

    private var totalWorkouts: Int { overview.totalWorkouts }

    private var totalSets: Int { overview.totalSets }

    /// Count of personal records the user currently holds — one per
    /// tracked lift across the archive (each exercise's all-time best
    /// is, by definition, a PR you hold). Drives the accented PR
    /// numeral in the lifetime odometer.
    private var personalRecords: Int {
        appState.analytics.progress.lazy.filter { $0.recordDate != nil }.count
    }

    private var lifetimeTonnage: ComparableTonnageSummary {
        overview.lifetimeTonnage
    }

    /// Volume label tuned for the lifetime totals card. The
    /// formatter handles the < 10k vs ≥ 10k branching (full-grouped
    /// vs compact "k") AND unit conversion in one call.
    private var volumeLabel: String {
        switch lifetimeTonnage.availability {
        case .complete:
            return WeightFormatter.volumeValue(lifetimeTonnage.knownSubtotal, unit: weightUnit)
        case .partial:
            return "\(WeightFormatter.volumeValue(lifetimeTonnage.knownSubtotal, unit: weightUnit))+"
        case .unavailable:
            return "—"
        }
    }

    private var lifetimeVolumeUnit: String? {
        lifetimeTonnage.availability == .unavailable ? nil : weightUnit.symbol
    }

    private var lifetimeVolumeLabel: String {
        switch lifetimeTonnage.availability {
        case .complete: "Total volume"
        case .partial: "Known volume · total unavailable"
        case .unavailable: "Volume unavailable"
        }
    }

    private func monthlyVolumeStat(_ recap: MonthlyRecap) -> Stat {
        switch recap.volumeAvailability {
        case .complete:
            return Stat(
                value: WeightFormatter.volumeValue(recap.volume, unit: weightUnit),
                unit: weightUnit.symbol,
                label: "volume"
            )
        case .partial:
            return Stat(
                value: "\(WeightFormatter.volumeValue(recap.volume, unit: weightUnit))+",
                unit: weightUnit.symbol,
                label: "known volume"
            )
        case .unavailable:
            return Stat(value: "—", label: "volume unavailable")
        }
    }
}

#Preview {
    NavigationStack {
        MeScreen(appState: AppState())
            .navigationTitle("Me")
    }
    .preferredColorScheme(.dark)
}
