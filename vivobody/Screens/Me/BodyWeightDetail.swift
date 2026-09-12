//
//  BodyWeightDetail.swift
//  vivobody
//
//  Full drill-down on body-weight progress:
//    • Hero header — current weight + delta chip + meta line
//    • Prominent Log button — same sheet used from the Me-tab card
//    • SwiftUI Charts line chart — area-filled, monotone curves,
//      weekly sampling for the unbounded All range
//    • Time-range chips — 1M / 3M / 6M / All (HIG-compliant 44pt)
//    • Recent table — lazy 40-row pages, context-delete, tap-to-edit
//
//  Empty state is intentionally light: the user only sees this
//  screen if they've already logged at least one entry (the Me-tab
//  card stays in its empty state otherwise).
//

import Charts
import SwiftData
import SwiftUI
import VivoKit

struct BodyWeightDetail: View {
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    @State private var range: TimeRange = .all
    @State private var logTarget: BodyWeightLogTarget? = nil
    @State private var pendingDelete: BodyWeightEntry? = nil
    @State private var saveError: SaveErrorBox? = nil
    @State private var recentEntryLimit = Self.recentEntryPageSize
    @State private var rangeAnchor = Date()

    private static let recentEntryPageSize = 40

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths, all
        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .oneMonth: "1M"
            case .threeMonths: "3M"
            case .sixMonths: "6M"
            case .all: "All"
            }
        }

        func cutoff(relativeTo date: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .oneMonth: calendar.date(byAdding: .month, value: -1, to: date)
            case .threeMonths: calendar.date(byAdding: .month, value: -3, to: date)
            case .sixMonths: calendar.date(byAdding: .month, value: -6, to: date)
            case .all: nil
            }
        }
    }

    var body: some View {
        BodyWeightDetailQuery(
            range: range,
            rangeAnchor: rangeAnchor,
            recentEntryLimit: recentEntryLimit
        ) { rangeEntries, recentEntries, hasMoreRecentEntries in
            let latest = recentEntries.first
            let latestDelta = recentEntries.count >= 2
                ? recentEntries[0].weight - recentEntries[1].weight
                : nil
            let visiblePoints = chartPoints(from: rangeEntries)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header(latest: latest, delta: latestDelta)
                    logButton
                    if visiblePoints.count >= 2 {
                        chart(points: visiblePoints)
                        rangeStrip
                    } else if !rangeEntries.isEmpty {
                        // Single-entry case — a quiet caption instead of
                        // an empty Charts frame (which renders a blank
                        // rectangle) or a boxy placeholder card.
                        singleEntryHint
                    }
                    if !recentEntries.isEmpty {
                        recentTable(
                            entries: recentEntries,
                            hasMore: hasMoreRecentEntries
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .screenBackground()
        .navigationTitle("Body Weight")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logTarget) { target in
            BodyWeightLogSheet(target: target)
        }
        .alert(
            "Delete entry?",
            isPresented: .constant(pendingDelete != nil),
            presenting: pendingDelete
        ) { entry in
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                context.delete(entry)
                do {
                    try context.saveOrRollback()
                    WidgetSnapshotWriter.writeAll(in: context)
                    pendingDelete = nil
                    Haptics.rigid()
                } catch {
                    saveError = SaveErrorBox(error)
                    pendingDelete = nil
                }
            }
        } message: { _ in
            Text("This entry will be removed from your history.")
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - Header

    private func header(latest: BodyWeightEntry?, delta: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current")
                .panelLegend()

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(currentWeightLabel(for: latest))
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)

                Spacer()

                if let delta, delta != 0 {
                    deltaChip(delta: delta)
                }
            }

            if let latest {
                Text("Last logged \(Self.dayFormatter.string(from: latest.date))")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            } else {
                Text("No entries yet")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private func deltaChip(delta: Double) -> some View {
        // For body weight, "up" vs "down" is value-neutral — some
        // people want to lose, some want to gain. We render the
        // sign honestly and use a neutral color so the chip doesn't
        // imply a moral direction (unlike strength PRs, where up =
        // always good).
        let isUp = delta > 0
        let chipColor = Ink.secondary
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(Typography.micro)
            Text(WeightFormatter.deltaString(delta, unit: unit, fractionDigits: 1))
                .font(Typography.metricMicro)
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(Capsule().fill(Surface.cardTintBright))
    }

    private func currentWeightLabel(for latest: BodyWeightEntry?) -> String {
        guard let latest else { return "—" }
        return WeightFormatter.string(latest.weight, unit: unit, fractionDigits: 1, includeUnit: false)
    }

    // MARK: - Log button

    private var logButton: some View {
        Button {
            Haptics.soft()
            logTarget = .create
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(Typography.headline)
                Text("Log weight")
                    .font(Typography.headline)
            }
            .foregroundStyle(Tint.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .coloredGlassControl(cornerRadius: Radius.chip, fill: Tint.primary)
            .softElevation()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart

    private func chart(points: [BodyWeightEntry]) -> some View {
        Chart {
            ForEach(points) { point in
                let displayWeight = WeightFormatter.toDisplay(point.weight, unit: unit)
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", displayWeight)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Ink.primary.opacity(Opacity.strong))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", displayWeight)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Ink.primary.opacity(0.18), Ink.primary.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(height: 220)
        // Swift Charts supplies the individual date/value elements; this
        // label and summary add context without collapsing those children.
        .accessibilityLabel("Body weight progress")
        .accessibilityValue(chartAccessibilitySummary(points: points))
    }

    private func chartAccessibilitySummary(points: [BodyWeightEntry]) -> String {
        guard let first = points.first, let last = points.last else {
            return "No body weight data"
        }
        let firstDate = first.date.formatted(date: .abbreviated, time: .omitted)
        let lastDate = last.date.formatted(date: .abbreviated, time: .omitted)
        let firstWeight = WeightFormatter.string(first.weight, unit: unit, fractionDigits: 1)
        let lastWeight = WeightFormatter.string(last.weight, unit: unit, fractionDigits: 1)
        return "\(points.count) entries. From \(firstWeight) on \(firstDate) to \(lastWeight) on \(lastDate)."
    }

    private var singleEntryHint: some View {
        Text("Log another entry to see your trend")
            .font(Typography.caption)
            .foregroundStyle(Ink.tertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Range strip

    private var rangeStrip: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases) { r in
                    rangeChip(r)
                }
            }
        }
    }

    private func rangeChip(_ r: TimeRange) -> some View {
        let isSelected = r == range
        return Button {
            Haptics.selection()
            range = r
        } label: {
            Text(r.label)
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.primary.opacity(Opacity.strong))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, Space.md)
                .coloredGlassControl(cornerRadius: Radius.chip, fill: isSelected ? Tint.primary : nil)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent table

    private func recentTable(entries: [BodyWeightEntry], hasMore: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Recent")
                .panelLegend()

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    Button {
                        Haptics.soft()
                        logTarget = .edit(entry)
                    } label: {
                        recentRow(entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            logTarget = .edit(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            pendingDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if idx < entries.count - 1 {
                        Rectangle()
                            .fill(Surface.edge)
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .contentCard(cornerRadius: Radius.card)

            if hasMore {
                Button("Load more") {
                    recentEntryLimit += Self.recentEntryPageSize
                }
                .font(Typography.headline)
                .foregroundStyle(Tint.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityHint("Shows older body weight entries")
            }
        }
    }

    private func recentRow(_ entry: BodyWeightEntry) -> some View {
        HStack(spacing: 12) {
            Text(Self.dayFormatter.string(from: entry.date))
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
                .frame(width: 110, alignment: .leading)

            Text(WeightFormatter.string(entry.weight, unit: unit, fractionDigits: 1))
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()

            Spacer()

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.primary.opacity(Opacity.faint))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Derived

    private func chartPoints(from chronologicalEntries: [BodyWeightEntry]) -> [BodyWeightEntry] {
        range == .all
            ? Self.weeklySamples(from: chronologicalEntries)
            : chronologicalEntries
    }

    /// The All range can span decades. Keeping the first measurement
    /// and the final measurement from each calendar week preserves the
    /// long-term shape while bounding a daily history to ~52 points/year.
    private static func weeklySamples(
        from chronologicalEntries: [BodyWeightEntry],
        calendar: Calendar = .current
    ) -> [BodyWeightEntry] {
        guard chronologicalEntries.count > 2,
              let first = chronologicalEntries.first,
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: first.date)?.start
        else { return chronologicalEntries }

        var samples = [first]
        var currentWeek = firstWeek
        var latestInWeek = first

        for entry in chronologicalEntries.dropFirst() {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start else {
                continue
            }
            if week == currentWeek {
                latestInWeek = entry
            } else {
                if samples.last?.id != latestInWeek.id {
                    samples.append(latestInWeek)
                }
                currentWeek = week
                latestInWeek = entry
            }
        }

        if samples.last?.id != latestInWeek.id {
            samples.append(latestInWeek)
        }
        return samples
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d  ·  yy"
        return f
    }()
}

/// Keeps SwiftData subscriptions proportional to what this screen can show:
/// the chart owns only its selected window, while the header and recent table
/// retain one bounded newest-first page plus a sentinel row for "Load more."
private struct BodyWeightDetailQuery<Content: View>: View {
    @Query private var rangeEntries: [BodyWeightEntry]
    @Query private var newestEntries: [BodyWeightEntry]

    private let recentEntryLimit: Int
    private let content: ([BodyWeightEntry], [BodyWeightEntry], Bool) -> Content

    init(
        range: BodyWeightDetail.TimeRange,
        rangeAnchor: Date,
        recentEntryLimit: Int,
        @ViewBuilder content: @escaping ([BodyWeightEntry], [BodyWeightEntry], Bool) -> Content
    ) {
        if let cutoff = range.cutoff(relativeTo: rangeAnchor) {
            _rangeEntries = Query(FetchDescriptor(
                predicate: #Predicate<BodyWeightEntry> { $0.date >= cutoff },
                sortBy: [SortDescriptor(\BodyWeightEntry.date, order: .forward)]
            ))
        } else {
            _rangeEntries = Query(FetchDescriptor(
                sortBy: [SortDescriptor(\BodyWeightEntry.date, order: .forward)]
            ))
        }

        var newestDescriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\BodyWeightEntry.date, order: .reverse)]
        )
        newestDescriptor.fetchLimit = recentEntryLimit + 1
        _newestEntries = Query(newestDescriptor)
        self.recentEntryLimit = recentEntryLimit
        self.content = content
    }

    var body: some View {
        content(
            rangeEntries,
            Array(newestEntries.prefix(recentEntryLimit)),
            newestEntries.count > recentEntryLimit
        )
    }
}
