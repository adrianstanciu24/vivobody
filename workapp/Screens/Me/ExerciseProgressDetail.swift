//
//  ExerciseProgressDetail.swift
//  workapp
//
//  Per-exercise progress drill-down from the Me tab. Big chart on
//  top, metric and time-range chips below, table of recent sessions
//  underneath. Uses SwiftUI's native Charts framework — gridlines,
//  axis labels, annotations all worth the extra chrome here, in
//  contrast to the MiniChart on the Me row.
//

import SwiftUI
import Charts

struct ExerciseProgressDetail: View {
    let progress: ExerciseProgress

    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var metric: Metric = .topWeight
    @State private var range: TimeRange = .all

    /// What the y-axis represents. Top-weight is the canonical
    /// "am I getting stronger" signal; volume tracks training output;
    /// e1RM smooths out rep-count variability across sessions.
    enum Metric: String, CaseIterable, Identifiable {
        case topWeight, volume, e1RM
        var id: String { rawValue }
        var label: String {
            switch self {
            case .topWeight: return "TOP WEIGHT"
            case .volume:    return "VOLUME"
            case .e1RM:      return "EST. 1RM"
            }
        }
        var shortLabel: String {
            switch self {
            case .topWeight: return "Top"
            case .volume:    return "Volume"
            case .e1RM:      return "e1RM"
            }
        }
    }

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

    private let prColor = Color(.sRGB, red: 1.0, green: 0.78, blue: 0.30, opacity: 1.0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                metricStrip
                chart
                rangeStrip
                recentTable
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(progress.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.group.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(progress.group.accent)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(WeightFormatter.string(progress.bestWeight, unit: unit, includeUnit: false))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                if let delta = progress.weightDelta, delta != 0 {
                    deltaChip(delta: delta)
                }
            }

            Text("ALL-TIME BEST")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.40))
        }
    }

    private func deltaChip(delta: Double) -> some View {
        let isUp = delta > 0
        let chipColor: Color = isUp
            ? Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)
            : Color(.sRGB, red: 0.96, green: 0.42, blue: 0.42, opacity: 1.0)
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(WeightFormatter.deltaString(delta, unit: unit))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(chipColor.opacity(0.15))
        )
    }

    // MARK: - Metric strip

    private var metricStrip: some View {
        HStack(spacing: 8) {
            ForEach(Metric.allCases) { m in
                metricChip(m)
            }
        }
    }

    private func metricChip(_ m: Metric) -> some View {
        let isSelected = m == metric
        return Button {
            Haptics.selection()
            metric = m
        } label: {
            Text(m.shortLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart

    private var chart: some View {
        let visible = visiblePoints
        return Chart {
            ForEach(visible) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.label, value(for: point))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.white.opacity(0.85))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(metric.label, value(for: point))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if point.isWeightPR && metric == .topWeight {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.label, value(for: point))
                    )
                    .symbol(.circle)
                    .symbolSize(60)
                    .foregroundStyle(prColor)
                }
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
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent table

    private var recentTable: some View {
        let visible = visiblePoints
        return VStack(alignment: .leading, spacing: 10) {
            Text("RECENT")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(visible.reversed().enumerated()), id: \.offset) { idx, point in
                    HStack(spacing: 12) {
                        Text(Self.dayFormatter.string(from: point.date))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 90, alignment: .leading)

                        Text("\(WeightFormatter.string(point.topWeight, unit: unit)) × \(point.topReps)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        if point.isWeightPR {
                            Text("PR")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(prColor))
                        }
                    }
                    .padding(.vertical, 10)

                    if idx < visible.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Derived

    private var visiblePoints: [ExerciseProgressPoint] {
        guard let cutoff = range.cutoff else { return progress.points }
        return progress.points.filter { $0.date >= cutoff }
    }

    /// Chart y-values are returned in the user's display unit so the
    /// auto-computed y-axis labels read naturally ("60", "70", "80"
    /// kg) instead of canonical lb numbers wearing a kg suffix.
    private func value(for point: ExerciseProgressPoint) -> Double {
        let canonical: Double
        switch metric {
        case .topWeight: canonical = point.topWeight
        case .volume:    canonical = point.totalVolume
        case .e1RM:      canonical = point.estimated1RM
        }
        return WeightFormatter.toDisplay(canonical, unit: unit)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d  ·  yy"
        return f
    }()
}
