//
//  MeScreen.swift
//  vivobody
//
//  Personal tab — a personal dashboard. Stacked surfaces:
//    • Your journey — engraved lifetime odometer + training-age rail.
//    • Milestones — the closest threshold leads a horizontal rail.
//    • Personal records — top standing records, full wall on tap.
//    • Body weight — latest entry + sparkline, linking to detail.
//    • This month — the current calendar month's recap.
//
//  Sections stay data-aware: Personal records does not reserve a dead
//  block before the first record, while body weight keeps an actionable
//  empty card. The mix of borderless hero, tactile rail, and resting
//  cards gives the long dashboard depth without turning it into tiles.
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

                    GroupSeparator(verticalPadding: Space.lg)
                    milestonesSection
                        .settleIn(1)

                    if hasStandingRecords {
                        GroupSeparator(verticalPadding: Space.lg)
                        personalRecordsSection
                            .settleIn(2)
                    }

                    GroupSeparator(verticalPadding: Space.lg)
                    bodyWeightSection
                        .settleIn(hasStandingRecords ? 3 : 2)
                    GroupSeparator(verticalPadding: Space.lg)
                    monthlyRecapSection
                        .settleIn(hasStandingRecords ? 4 : 3)
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
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Ink.secondary)
                }
                .tint(Ink.secondary)
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
                trailing: bodyWeightEntries.isEmpty ? nil : "View trend"
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

    /// Quiet resting-surface empty state: one caption line and a compact
    /// left-aligned action — no icon or centered full-screen treatment.
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
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .contentCard(bright: true)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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

    /// Lifetime totals as an *odometer*: one engraved volume numeral is
    /// the whole story, with workouts / sets / PRs trailing as a quiet
    /// single-line spec and the training-age rail anchoring it in time.
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
                journeyHero
            }
        }
    }

    /// Borderless hero relief: the engraved numeral is the material,
    /// shared with History's volume readouts. The only orange is the
    /// live endpoint on the training-age rail below it.
    private var journeyHero: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CarvedVolumeText(
                    value: volumeLabel,
                    unit: lifetimeVolumeUnit ?? "",
                    size: 56
                )
                Text(lifetimeVolumeLabel)
                    .panelLegend()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(volumeLabel)\(lifetimeVolumeUnit.map { " \($0)" } ?? "") \(lifetimeVolumeLabel)"
            )

            lifetimeLine

            if let ageText = JourneyFormatting.trainingAgeText(
                since: overview.trainingSince
            ) {
                JourneyTimeline(caption: ageText)
            }
        }
        .padding(.vertical, Space.md)
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
                    let featuredIndex = featuredMilestoneIndex(in: milestones)
                    let orderedIndices = milestoneOrder(
                        for: milestones,
                        featuredIndex: featuredIndex
                    )
                    // Positional identity: Milestone ids are freshly minted
                    // on every recompute, which would re-fire powerOn.
                    ForEach(Array(orderedIndices.enumerated()), id: \.offset) { order, index in
                        MilestoneBadge(
                            milestone: milestones[index],
                            featured: index == featuredIndex
                        )
                        .powerOn(order)
                    }
                }
            }
        }
    }

    /// The unfinished category nearest its visible threshold leads the
    /// rail. Equal progress keeps the domain order, avoiding arbitrary
    /// reshuffles at a fresh zeroed state.
    private func featuredMilestoneIndex(in milestones: [Milestone]) -> Int? {
        var bestIndex: Int?
        for index in milestones.indices {
            let candidate = milestones[index]
            guard !candidate.achieved, candidate.targetLabel != nil else { continue }
            guard let currentBest = bestIndex else {
                bestIndex = index
                continue
            }
            if candidate.targetProgress > milestones[currentBest].targetProgress {
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func milestoneOrder(
        for milestones: [Milestone],
        featuredIndex: Int?
    ) -> [Int] {
        guard let featuredIndex else { return Array(milestones.indices) }
        return [featuredIndex] + milestones.indices.filter { $0 != featuredIndex }
    }

    // MARK: - Personal records

    /// Top standing records as a preview; the full wall is one tap
    /// away via the header. The parent inserts this section only once
    /// a record exists, avoiding an empty chapter in the dashboard.
    private var personalRecordsSection: some View {
        let records = appState.analytics.progress.standingRecords
        return VStack(alignment: .leading, spacing: Space.md) {
            NavigationLink {
                PersonalRecordsScreen()
            } label: {
                SectionHeader(
                    title: "Personal records",
                    trailing: records.count > 3 ? "See all" : nil
                )
                .frame(minHeight: Space.tapMin)
                .contentShape(Rectangle())
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

    private var hasStandingRecords: Bool {
        !appState.analytics.progress.standingRecords.isEmpty
    }

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

/// A qualitative start-to-now rail. It does not pretend training age
/// is progress toward an arbitrary goal; it simply gives the lifetime
/// caption a physical origin and a live endpoint.
private struct JourneyTimeline: View {
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: 0) {
                Circle()
                    .fill(Ink.quaternary)
                    .frame(width: 6, height: 6)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Ink.quaternary, Tint.primary.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Circle()
                    .fill(Tint.primary)
                    .frame(width: 7, height: 7)
                    .shadow(color: Tint.primary.opacity(0.42), radius: 4)
            }

            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: Space.sm)
                Text("Today")
                    .panelLegend()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }
}

#Preview {
    NavigationStack {
        MeScreen(appState: AppState())
            .navigationTitle("Me")
    }
    .preferredColorScheme(.dark)
}
