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
                groupSeparator
                preferencesSection
                    .settleIn(2)
                footer
                    .padding(.top, Space.xxl)
                    .settleIn(3)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            // Extra tail so the last Progress row clears the floating
            // tab bar at rest instead of peeking out from under it.
            .padding(.bottom, Space.section + Space.md)
        }
        .forgeBackground()
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
    /// a single color-preserving glass action — no ghost preview, no card.
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
                    .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
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

    // MARK: - Stats

    private static let volumeHero = Font.system(size: 52, weight: .bold, design: .monospaced)
    private static let monoStat = Font.system(size: 22, weight: .bold, design: .monospaced)

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
                        valueFont: Self.volumeHero
                    )
                    lifetimeLine
                }
            }
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
            value.font = .system(size: 15, weight: .semibold)
            value.foregroundColor = part.accent ? Tint.primary : Ink.primary
            result += value

            var label = AttributedString(" " + part.label)
            label.font = .system(size: 15, weight: .regular)
            label.foregroundColor = Ink.tertiary
            result += label
        }
        return result
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
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
            .coloredGlassControl(cornerRadius: 16)
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

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(WeightUnit.allCases) { unit in
                        weightUnitChip(unit)
                    }
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
            .coloredGlassControl(cornerRadius: 12, fill: isSelected ? Tint.inProgress : nil)
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
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(restOptions, id: \.self) { seconds in
                            restChip(seconds: seconds)
                        }
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
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
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
