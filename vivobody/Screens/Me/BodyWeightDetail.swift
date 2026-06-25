//
//  BodyWeightDetail.swift
//  vivobody
//
//  Full drill-down on body-weight progress:
//    • Hero header — current weight + delta chip + meta line
//    • Prominent Log button — same sheet used from the Me-tab card
//    • SwiftUI Charts line chart — area-filled, monotone curves
//    • Time-range chips — 1M / 3M / 6M / All (HIG-compliant 44pt)
//    • Recent table — swipe-to-delete, tap-to-edit
//
//  Empty state is intentionally light: the user only sees this
//  screen if they've already logged at least one entry (the Me-tab
//  card stays in its empty state otherwise).
//

import SwiftUI
import SwiftData
import Charts

struct BodyWeightDetail: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \BodyWeightEntry.date, order: .forward)
    private var entries: [BodyWeightEntry]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var range: TimeRange = .all
    @State private var logTarget: BodyWeightLogTarget? = nil
    @State private var pendingDelete: BodyWeightEntry? = nil

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneMonth:    return "1M"
            case .threeMonths: return "3M"
            case .sixMonths:   return "6M"
            case .all:         return "All"
            }
        }
        var cutoff: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth:    return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: Date())
            case .all:         return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                logButton
                if visiblePoints.count >= 2 {
                    chart
                    rangeStrip
                } else if !entries.isEmpty {
                    // Single-entry case — a quiet caption instead of
                    // an empty Charts frame (which renders a blank
                    // rectangle) or a boxy placeholder card.
                    singleEntryHint
                }
                if !entries.isEmpty {
                    recentTable
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 16)
        }
        .background(Surface.background.ignoresSafeArea())
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
                try? context.save()
                pendingDelete = nil
                Haptics.rigid()
            }
        } message: { _ in
            Text("This entry will be removed from your history.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current")
                .sectionLabelStyle(Opacity.medium)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(currentWeightLabel)
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.primary.opacity(Opacity.medium))

                Spacer()

                if let delta = entries.latestDelta, delta != 0 {
                    deltaChip(delta: delta)
                }
            }

            if let last = entries.latest {
                Text("Last logged \(Self.dayFormatter.string(from: last.date))")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.primary.opacity(Opacity.soft))
            } else {
                Text("No entries yet")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.primary.opacity(Opacity.soft))
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

    private var currentWeightLabel: String {
        guard let last = entries.latest else { return "—" }
        return WeightFormatter.string(last.weight, unit: unit, fractionDigits: 1, includeUnit: false)
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

    private var chart: some View {
        Chart {
            ForEach(visiblePoints) { point in
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
                    .foregroundStyle(Ink.primary.opacity(Opacity.medium))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.primary.opacity(Opacity.medium))
            }
        }
        .frame(height: 220)
    }

    private var singleEntryHint: some View {
        Text("Log another entry to see your trend")
            .font(Typography.caption)
            .foregroundStyle(Ink.primary.opacity(Opacity.soft))
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

    private var recentTable: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Recent")
                .sectionLabelStyle(Opacity.medium)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(reversedEntries.enumerated()), id: \.element.id) { idx, entry in
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

                    if idx < reversedEntries.count - 1 {
                        Rectangle()
                            .fill(Surface.edge)
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .contentCard(cornerRadius: Radius.card)
        }
    }

    private func recentRow(_ entry: BodyWeightEntry) -> some View {
        HStack(spacing: 12) {
            Text(Self.dayFormatter.string(from: entry.date))
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.primary.opacity(Opacity.medium))
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

    private var visiblePoints: [BodyWeightEntry] {
        let chrono = entries.chronological
        guard let cutoff = range.cutoff else { return chrono }
        return chrono.filter { $0.date >= cutoff }
    }

    private var reversedEntries: [BodyWeightEntry] {
        entries.chronological.reversed()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d  ·  yy"
        return f
    }()
}
