//
//  MeScreen.swift
//  vivobody
//
//  Personal tab. Two stacked surfaces:
//    • YOUR JOURNEY — lifetime totals across all archived sessions
//      (workouts logged, sets completed, total volume).
//    • PREFERENCES — defaultable rest seconds, haptics on/off.
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

    /// Recognizable "complete" green used elsewhere in the app
    /// (summary card accent, complete-state set rows). Re-used here
    /// for the Haptics toggle so its ON state has clear contrast
    /// against the white thumb rather than reading as a blank pill.
    private let toggleOnGreen = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                statsSection
                if weeklyComparison.hasAnyActivity {
                    weeklySection
                }
                bodyWeightSection
                if !progressEntries.isEmpty {
                    progressSection
                }
                preferencesSection
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(for: ExerciseProgress.self) { entry in
            ExerciseProgressDetail(progress: entry)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Body weight")
                    .sectionLabelStyle(0.60)
                Spacer()
                if !bodyWeightEntries.isEmpty {
                    Text("Tap for detail")
                        .sectionLabelStyle(0.40)
                }
            }

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

    private var bodyWeightEmptyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    GlassSphere(size: 64, tint: Tint.primary)
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 26, weight: .light))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Tint.primary, .white.opacity(0.30))
                }

                Text("Track your body weight to see how it trends alongside your training.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.soft()
                logTarget = .create
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Log Weight")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Capsule().fill(Tint.primary))
                .primaryGlow(Tint.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var bodyWeightPopulatedCard: some View {
        // Sparkline series is chronological so the line reads
        // left-to-right as time-forward, matching the detail chart.
        let sparkValues = bodyWeightEntries.chronological.map(\.weight)
        let latest = bodyWeightEntries.latest
        let delta = bodyWeightEntries.latestDelta

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(latest.map {
                        WeightFormatter.string($0.weight, unit: weightUnit, fractionDigits: 1, includeUnit: false)
                    } ?? "—")
                        .font(Typography.statValue)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(weightUnit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
                if let delta {
                    bodyWeightDeltaLabel(delta: delta)
                } else if let latest {
                    Text("First entry · \(Self.shortDayFormatter.string(from: latest.date))")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }

            Spacer(minLength: 8)

            if sparkValues.count >= 2 {
                MiniChart(values: sparkValues, lineColor: Tint.primary, fillColor: Tint.primary)
                    .frame(width: 96, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.30))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .contentShape(Rectangle())
    }

    private func bodyWeightDeltaLabel(delta: Double) -> some View {
        let isUp = delta > 0
        let deltaText = WeightFormatter.deltaString(delta, unit: weightUnit, fractionDigits: 1)
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text("\(deltaText) since last entry")
                .font(Typography.caption)
        }
        .foregroundStyle(.white.opacity(0.60))
    }

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    // MARK: - Weekly comparison

    /// Aggregated current vs prior week. Recomputed each render —
    /// dataset is tiny (weeks are bounded) and memoizing would risk
    /// staleness after history edits.
    private var weeklyComparison: WeeklyComparison {
        completedSessions.weeklyComparison()
    }

    private var weeklySection: some View {
        let comp = weeklyComparison
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This week")
                    .sectionLabelStyle(0.60)
                Spacer()
                Text("vs last week")
                    .sectionLabelStyle(0.40)
            }

            HStack(spacing: 0) {
                weeklyStat(
                    value: "\(comp.thisWeek.workouts)",
                    previous: comp.lastWeek.workouts,
                    delta: Double(comp.workoutsDelta),
                    label: "Workouts"
                )
                weeklyDivider
                weeklyStat(
                    value: "\(comp.thisWeek.sets)",
                    previous: comp.lastWeek.sets,
                    delta: Double(comp.setsDelta),
                    label: "Sets"
                )
                weeklyDivider
                weeklyStat(
                    value: WeightFormatter.volumeValue(comp.thisWeek.volume, unit: weightUnit),
                    valueUnit: weightUnit.symbol,
                    previous: comp.lastWeek.volume,
                    delta: comp.volumeDelta,
                    label: "Volume",
                    isVolume: true
                )
            }
            .padding(.vertical, 8)
        }
        .padding(20)
        .glassCard()
    }

    /// One weekly stat column — current value (large), small delta
    /// chip below. `previous == 0` is treated specially: there's
    /// nothing to compare to, so we render a neutral "first week"
    /// indicator instead of a misleading +∞ chip.
    private func weeklyStat(
        value: String,
        valueUnit: String? = nil,
        previous: some Numeric,
        delta: Double,
        label: String,
        isVolume: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(Typography.statValue)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let valueUnit {
                    Text(valueUnit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            weeklyDeltaIndicator(delta: delta, isVolume: isVolume, previousIsZero: previousIsZero(previous))
            Text(label)
                .sectionLabelStyle(0.50)
        }
        .frame(maxWidth: .infinity)
    }

    /// Generic helper for "is this Numeric value zero?" — avoids
    /// a duplicate Int/Double overload for the call sites above.
    private func previousIsZero(_ value: some Numeric) -> Bool {
        // Numeric doesn't conform to Equatable by itself, so route
        // through the AdditiveArithmetic conformance.
        if let int = value as? Int { return int == 0 }
        if let dbl = value as? Double { return dbl == 0 }
        return false
    }

    /// The little ↑+12 / ↓−3 / — chip under each weekly stat. Green
    /// for up, red for down, dimmed white for flat. When the prior
    /// week had nothing logged we drop the arrow entirely and show
    /// "FIRST WEEK" instead of a misleading delta.
    private func weeklyDeltaIndicator(delta: Double, isVolume: Bool, previousIsZero: Bool) -> some View {
        Group {
            if previousIsZero {
                Text("First week")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.40))
            } else if delta == 0 {
                HStack(spacing: 3) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                    Text("no change")
                        .font(Typography.caption)
                }
                .foregroundStyle(.white.opacity(0.50))
            } else {
                let isUp = delta > 0
                let color: Color = isUp ? Tint.success : Tint.danger
                let label: String = isVolume
                    ? WeightFormatter.deltaString(delta, unit: weightUnit)
                    : "\(isUp ? "+" : "")\(Int(delta))"
                HStack(spacing: 3) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(label)
                        .font(Typography.caption)
                }
                .foregroundStyle(color)
            }
        }
    }

    private var weeklyDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 56)
    }

    // MARK: - Progress

    /// Per-exercise progress series across the archive. Recomputed
    /// on each render — with realistic archive sizes (hundreds of
    /// sessions × handful of exercises) this is well under a frame.
    /// Memoization would just risk staleness after edit/delete.
    private var progressEntries: [ExerciseProgress] {
        completedSessions.progressByExercise
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Progress")
                    .sectionLabelStyle(0.60)
                Spacer()
                Text("Tap for detail")
                    .sectionLabelStyle(0.40)
            }

            VStack(spacing: 0) {
                ForEach(Array(progressEntries.enumerated()), id: \.element.id) { idx, entry in
                    NavigationLink(value: entry) {
                        progressRow(entry)
                    }
                    .buttonStyle(.plain)

                    if idx < progressEntries.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .glassCard()
        }
    }

    private func progressRow(_ entry: ExerciseProgress) -> some View {
        let weights = entry.points.map(\.topWeight)
        let prSet: Set<Int> = Set(
            entry.points.enumerated()
                .filter { $0.element.isWeightPR }
                .map(\.offset)
        )
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.group.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(entry.group.accent)
            }
            .frame(minWidth: 90, alignment: .leading)

            MiniChart(values: weights, prIndices: prSet, lineColor: Tint.primary, fillColor: Tint.primary)
                .frame(width: 80, height: 32)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(WeightFormatter.string(entry.bestWeight, unit: weightUnit, includeUnit: false))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(weightUnit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
                if let delta = entry.weightDelta {
                    trendIndicator(delta: delta)
                } else {
                    Text("—")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func trendIndicator(delta: Double) -> some View {
        let isUp = delta > 0
        let isFlat = delta == 0
        let color: Color = isFlat
            ? .white.opacity(0.45)
            : (isUp ? Tint.success : Tint.danger)
        let symbol: String = isFlat ? "minus" : (isUp ? "arrow.up.right" : "arrow.down.right")
        let valueText: String = isFlat
            ? "no change"
            : WeightFormatter.deltaString(delta, unit: weightUnit)
        return HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            Text(valueText)
                .font(Typography.caption)
        }
        .foregroundStyle(color)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your journey")
                    .sectionLabelStyle(0.60)
                Spacer()
                if !completedSessions.isEmpty {
                    Text("Last 12 weeks")
                        .sectionLabelStyle(0.40)
                }
            }

            if completedSessions.isEmpty {
                emptyJourneyTile
            } else {
                journeyTiles
            }
        }
    }

    /// Three glass tiles, each with a hero number + sparkline. Trend
    /// arrow uses the most-recent-4-weeks average vs the prior 8-week
    /// average so a single quiet week doesn't read as a downturn.
    private var journeyTiles: some View {
        let series = completedSessions.weeklySeries()
        let workoutsSeries = series.map { Double($0.workouts) }
        let setsSeries = series.map { Double($0.sets) }
        let volumeSeries = series.map(\.volume)

        return HStack(spacing: 10) {
            journeyTile(
                value: "\(totalWorkouts)",
                unit: nil,
                label: "Workouts",
                series: workoutsSeries
            )
            journeyTile(
                value: "\(totalSets)",
                unit: nil,
                label: "Sets",
                series: setsSeries
            )
            journeyTile(
                value: volumeLabel,
                unit: weightUnit.symbol,
                label: "Volume",
                series: volumeSeries
            )
        }
    }

    private func journeyTile(
        value: String,
        unit: String?,
        label: String,
        series: [Double]
    ) -> some View {
        let trendingUp = isTrendingUp(series)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }

            if series.count >= 2 && series.contains(where: { $0 > 0 }) {
                MiniChart(
                    values: series,
                    lineColor: trendingUp ? Tint.primary : .white,
                    fillColor: trendingUp ? Tint.primary : .white
                )
                .frame(height: 26)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text(label)
                .sectionLabelStyle(0.55)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassChip(cornerRadius: 18, tint: trendingUp ? Tint.primary : nil)
        .shadow(
            color: trendingUp ? Tint.primary.opacity(0.30) : .clear,
            radius: 14, y: 4
        )
    }

    /// Compares the trailing 4-week average vs the prior 8-week
    /// average — gives the "trending up" tint enough inertia to
    /// ignore a single quiet week.
    private func isTrendingUp(_ series: [Double]) -> Bool {
        guard series.count >= 6 else { return false }
        let recent = series.suffix(4)
        let earlier = series.dropLast(4)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.isEmpty
            ? 0
            : earlier.reduce(0, +) / Double(earlier.count)
        return recentAvg > earlierAvg
    }

    private var emptyJourneyTile: some View {
        HStack(spacing: 14) {
            ZStack {
                GlassSphere(size: 56, tint: Tint.primary)
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Tint.primary, .white.opacity(0.30))
                    .symbolEffect(.breathe.pulse, options: .repeating)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Log your first workout")
                    .sectionHeadingStyle()
                Text("Your stats and trends land here.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .sectionLabelStyle(0.60)

            VStack(alignment: .leading, spacing: 18) {
                weightUnitRow
                rowDivider
                restRow
                rowDivider
                hapticsRow
                rowDivider
                resetCatalogRow
            }
            .padding(20)
            .glassCard()
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reset Exercise Catalog")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Restore the original 90 exercises")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Wipes and reseeds the exercise catalog")
    }

    private var weightUnitRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight Unit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Displayed across the app — storage stays canonical")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Text(weightUnit.symbol)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
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
            .foregroundStyle(isSelected ? .black : .white.opacity(0.80))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Tint.primary)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? Tint.primary.opacity(0.40) : .clear,
                radius: 14, y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unit.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Rest")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Between sets — used by the rest timer")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Text("\(defaultRestSeconds)s")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                .foregroundStyle(isSelected ? .black : .white.opacity(0.80))
                .frame(minWidth: 56, minHeight: 44)
                .padding(.horizontal, 14)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Tint.primary)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: isSelected ? Tint.primary.opacity(0.35) : .clear,
                    radius: 12, y: 2
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(seconds) second rest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hapticsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Haptics")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Taps and patterns throughout the app")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
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
            .tint(Tint.success)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("vivobody")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Derived

    private var totalWorkouts: Int { completedSessions.count }

    private var totalSets: Int {
        completedSessions.reduce(0) { $0 + $1.totalSets }
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
