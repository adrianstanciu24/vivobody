//
//  MeScreen.swift
//  vivobody
//
//  Personal tab. Two stacked surfaces:
//    • Your journey — lifetime totals across all archived sessions
//      (workouts logged, sets completed, total volume).
//    • Preferences — defaultable rest seconds, haptics on/off.
//
//  Settings persist via @AppStorage (UserDefaults). The Haptics
//  engine reads its enabled flag directly from UserDefaults on every
//  emission, so toggling here takes effect immediately throughout
//  the app with no extra wiring. The weight unit follows the same
//  pattern — every display site and every weight scrubber reads
//  the unit at render time, so flipping the toggle propagates
//  instantly across the app.
//

import SwiftUI
import SwiftData

struct MeScreen: View {
    @Bindable var appState: AppState

    /// SwiftData context — needed for the Reset Catalog action,
    /// which wipes and re-seeds the ExerciseCatalogItem store.
    /// Pulled from the environment lazily so MeScreen continues
    /// to render via @Bindable without any constructor changes.
    @Environment(\.modelContext) private var modelContext

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

    @AppStorage(SettingsKey.hapticsEnabled)
    private var hapticsEnabled: Bool = SettingsDefaults.hapticsEnabled

    @AppStorage(SettingsKey.defaultRestSeconds)
    private var defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    /// Drives the inline log sheet presented from the empty-state
    /// card. Populated state navigates to detail (which has its own
    /// log sheet) so the same affordance never collides.
    @State private var logTarget: BodyWeightLogTarget? = nil

    /// Controls the destructive-confirmation alert for "Reset
    /// Exercise Catalog." Bound to the alert's `isPresented`.
    @State private var isConfirmingCatalogReset: Bool = false

    /// Common rest values that cover the bulk of strength-training
    /// programs. Surfaced as a horizontal chip selector — picking a
    /// value is a single tap with no keyboard or sheet round-trip.
    private let restOptions: [Int] = [30, 60, 90, 120, 180]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statsSection
                    .settleIn(0)
                groupSeparator
                bodyWeightSection
                    .settleIn(1)
                if !progressEntries.isEmpty {
                    groupSeparator
                    progressSection
                        .settleIn(2)
                }
                groupSeparator
                preferencesSection
                    .settleIn(3)
                footer
                    .padding(.top, Space.xxl)
                    .settleIn(4)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            // Extra tail so the last Progress row clears the floating
            // tab bar at rest instead of peeking out from under it.
            .padding(.bottom, Space.section + Space.md)
        }
        .forgeBackground()
        .navigationDestination(for: ExerciseProgress.self) { entry in
            ExerciseProgressDetail(progress: entry)
        }
        .sheet(item: $logTarget) { target in
            BodyWeightLogSheet(target: target)
        }
    }

    // MARK: - Group separator

    /// Full-width hairline between two major groups, carrying generous
    /// air on both sides so each group reads as its own instrument —
    /// the same device SessionDetail uses between its hero and the
    /// exercise breakdown. This is what gives the screen its rhythm;
    /// the flat 24pt gap alone read as crowded.
    private var groupSeparator: some View {
        SectionDivider()
            .padding(.vertical, Space.xl)
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
    /// a single flat lime action — no ghost preview, no card.
    private var bodyWeightEmptyCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Track your body weight to see how it trends alongside your training.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.soft()
                logTarget = .create
            } label: {
                Text("Log weight")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Tint.onAccent)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Tint.inProgress))
            }
            .buttonStyle(.plain)
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
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(latest.map {
                        WeightFormatter.string($0.weight, unit: weightUnit, fractionDigits: 1, includeUnit: false)
                    } ?? "—")
                        .font(Self.monoStat)
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
                .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 10, weight: .bold))
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

    // MARK: - Progress

    /// Per-exercise progress series across the archive. Recomputed
    /// on each render — with realistic archive sizes (hundreds of
    /// sessions × handful of exercises) this is well under a frame.
    /// Memoization would just risk staleness after edit/delete.
    private var progressEntries: [ExerciseProgress] {
        completedSessions.progressByExercise
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Progress", trailing: "Tap for detail")

            VStack(spacing: 0) {
                ForEach(Array(progressEntries.enumerated()), id: \.element.id) { idx, entry in
                    if idx > 0 { SectionDivider() }
                    NavigationLink(value: entry) {
                        progressRow(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func progressRow(_ entry: ExerciseProgress) -> some View {
        let isDuration = entry.trackingMode == .duration
        let chartValues = isDuration ? entry.points.map(\.topDuration) : entry.points.map(\.topWeight)
        let prSet: Set<Int> = Set(
            entry.points.enumerated()
                .filter { $0.element.isWeightPR }
                .map(\.offset)
        )
        return HStack(spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(entry.name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text(entry.group.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(minWidth: 88, alignment: .leading)

            MiniChart(values: chartValues, prIndices: prSet, lineColor: Tint.inProgress, fillColor: Tint.inProgress)
                .frame(width: 112, height: 44)

            Spacer(minLength: Space.md)

            VStack(alignment: .trailing, spacing: Space.xs) {
                if isDuration {
                    Text(DurationFormatter.string(entry.bestDuration))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(WeightFormatter.string(entry.bestWeight, unit: weightUnit, includeUnit: false))
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(Ink.primary)
                            .monospacedDigit()
                        Text(weightUnit.symbol)
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.tertiary)
                    }
                }

                if isDuration {
                    if let delta = entry.durationDelta {
                        trendChip(delta: delta, valueText: delta == 0 ? "no change" : DurationFormatter.deltaString(delta))
                    } else {
                        Text("—")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                    }
                } else if let delta = entry.weightDelta {
                    trendChip(delta: delta, valueText: delta == 0 ? "no change" : WeightFormatter.deltaString(delta, unit: weightUnit))
                } else {
                    Text("—")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
            }
        }
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Trend pill shared by weight and duration progress rows — the
    /// arrow + color come from the delta's sign; the text is
    /// pre-formatted by the caller (weight delta or mm:ss delta).
    private func trendChip(delta: Double, valueText: String) -> some View {
        let isUp = delta > 0
        let isFlat = delta == 0
        let color: Color = isFlat
            ? Ink.tertiary
            : (isUp ? Tint.inProgress : Tint.danger)
        let symbol: String = isFlat ? "minus" : (isUp ? "arrow.up.right" : "arrow.down.right")
        return HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            Text(valueText)
                .font(Typography.caption)
        }
        .foregroundStyle(color)
    }

    // MARK: - Stats

    private static let volumeHero = Font.system(size: 52, weight: .bold, design: .monospaced)
    private static let monoStat = Font.system(size: 22, weight: .bold, design: .monospaced)

    /// Lifetime totals as an instrument: total volume as a large
    /// monospaced hero, with workouts / sets / PRs on a hairline
    /// stat strip beneath. This is the all-time *odometer* — the
    /// counterpart to History's this-week *log*. The accented PR
    /// count gives Me an achievement identity History doesn't carry.
    /// No tiles, no glass — the numbers carry it.
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Your journey",
                trailing: completedSessions.isEmpty ? nil : "All time"
            )

            if completedSessions.isEmpty {
                emptyJourney
            } else {
                VStack(alignment: .leading, spacing: Space.xl) {
                    MetricView(
                        label: "Total volume",
                        value: volumeLabel,
                        unit: weightUnit.symbol,
                        valueFont: Self.volumeHero
                    )
                    StatStrip(
                        stats: [
                            Stat(value: "\(totalWorkouts)", label: "Workouts"),
                            Stat(value: "\(totalSets)", label: "Sets"),
                            Stat(
                                value: "\(personalRecords)",
                                label: personalRecords == 1 ? "PR" : "PRs",
                                accent: personalRecords > 0
                            ),
                        ],
                        valueFont: Self.monoStat
                    )
                }
            }
        }
    }

    /// Type-forward empty journey — a quiet heading and one line, no
    /// ghost tiles.
    private var emptyJourney: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Log your first workout")
                .sectionHeadingStyle()
            Text("Your lifetime volume, workouts, and sets will land here.")
                .font(Typography.body)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Preferences")

            VStack(alignment: .leading, spacing: Space.lg + 2) {
                weightUnitRow
                rowDivider
                restRow
                rowDivider
                hapticsRow
                rowDivider
                resetCatalogRow
            }
        }
        .alert(
            "Reset Exercise Catalog?",
            isPresented: $isConfirmingCatalogReset
        ) {
            Button("Reset", role: .destructive) {
                ExerciseCatalogItem.resetToDefaults(in: modelContext)
                Haptics.thunk()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Restores the original 90 exercises. Any custom exercises and edits will be removed. Templates and workout history are not affected.")
        }
    }

    /// Destructive-action row inside Preferences. Tapping the whole
    /// row opens a confirmation alert — never single-tap destructive,
    /// per the rest of the app's pattern (delete set, cancel
    /// workout, etc.).
    private var resetCatalogRow: some View {
        Button {
            Haptics.soft()
            isConfirmingCatalogReset = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Reset Exercise Catalog")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Restore the original 90 exercises")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Wipes and reseeds the exercise catalog")
    }

    private var weightUnitRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Weight Unit")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Displayed across the app — storage stays canonical")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Text(weightUnit.symbol)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Ink.primary)
            }

            HStack(spacing: Space.sm) {
                ForEach(WeightUnit.allCases) { unit in
                    weightUnitChip(unit)
                }
            }
        }
    }

    private func weightUnitChip(_ unit: WeightUnit) -> some View {
        let isSelected = unit == weightUnit
        return Button {
            Haptics.selection()
            weightUnitRaw = unit.rawValue
        } label: {
            VStack(spacing: 2) {
                Text(unit.symbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Text(unit.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.75)
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Tint.inProgress)
                }
            }
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Surface.edge, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unit.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Default Rest")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Between sets — used by the rest timer")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Text("\(defaultRestSeconds)s")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Ink.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(restOptions, id: \.self) { seconds in
                        restChip(seconds: seconds)
                    }
                }
            }
        }
    }

    private func restChip(seconds: Int) -> some View {
        let isSelected = defaultRestSeconds == seconds
        return Button {
            Haptics.selection()
            defaultRestSeconds = seconds
        } label: {
            Text("\(seconds)s")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minWidth: 56, minHeight: 44)
                .padding(.horizontal, Space.md + 2)
                .background {
                    if isSelected {
                        Capsule().fill(Tint.inProgress)
                    }
                }
                .overlay {
                    if !isSelected {
                        Capsule().stroke(Surface.edge, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(seconds) second rest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hapticsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Haptics")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Taps and patterns throughout the app")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { hapticsEnabled },
                set: { newValue in
                    hapticsEnabled = newValue
                    if newValue {
                        // The @AppStorage write propagates synchronously
                        // to UserDefaults, so the next Haptics emission
                        // reads `true` — this soft tap plays as a
                        // confirmation that haptics just came back on.
                        Haptics.soft()
                    }
                }
            ))
            .labelsHidden()
            .tint(Tint.inProgress)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("vivobody")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.sm)
    }

    // MARK: - Derived

    private var totalWorkouts: Int { completedSessions.count }

    private var totalSets: Int {
        completedSessions.reduce(0) { $0 + $1.totalSets }
    }

    /// Count of personal records the user currently holds — one per
    /// tracked lift in the Progress list (each exercise's all-time
    /// best is, by definition, a PR you hold). Aligned with the
    /// Progress section right below so the number and the list agree.
    private var personalRecords: Int { progressEntries.count }

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
