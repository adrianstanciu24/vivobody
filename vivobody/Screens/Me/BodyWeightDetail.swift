//
//  BodyWeightDetail.swift
//  vivobody
//
//  Full drill-down on body-weight progress. Architecture parallels
//  ExerciseProgressDetail:
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
            VStack(alignment: .leading, spacing: 22) {
                header
                logButton
                if visiblePoints.count >= 2 {
                    chart
                    rangeStrip
                } else if !entries.isEmpty {
                    // Single-entry case — show a placeholder rather
                    // than an empty Charts frame, which otherwise
                    // renders an awkward blank rectangle.
                    singleEntryPlaceholder
                }
                if !entries.isEmpty {
                    recentTable
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Body Weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
                .sectionLabelStyle(0.60)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(currentWeightLabel)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                if let delta = entries.latestDelta, delta != 0 {
                    deltaChip(delta: delta)
                }
            }

            if let last = entries.latest {
                Text("Last logged \(Self.dayFormatter.string(from: last.date))")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("No entries yet")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.45))
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
        let chipColor = Color.white.opacity(0.85)
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(WeightFormatter.deltaString(delta, unit: unit, fractionDigits: 1))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.10)))
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
                    .font(.system(size: 16, weight: .semibold))
                Text("Log weight")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tint.primary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.40), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .primaryGlow(Tint.primary)
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
                .foregroundStyle(.white.opacity(0.85))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", displayWeight)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .frame(height: 220)
    }

    private var singleEntryPlaceholder: some View {
        HStack {
            Spacer()
            Text("Log another entry to see your trend")
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
        .frame(height: 120)
        .glassChip(cornerRadius: 16)
    }

    // MARK: - Range strip

    private var rangeStrip: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases) { r in
                rangeChip(r)
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
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.80))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Tint.primary : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: isSelected ? Tint.primary.opacity(0.35) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent table

    private var recentTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .sectionLabelStyle(0.60)

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
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .glassCard(cornerRadius: 18)
        }
    }

    private func recentRow(_ entry: BodyWeightEntry) -> some View {
        HStack(spacing: 12) {
            Text(Self.dayFormatter.string(from: entry.date))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 110, alignment: .leading)

            Text(WeightFormatter.string(entry.weight, unit: unit, fractionDigits: 1))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.30))
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
