//
//  WidgetChrome.swift
//  vivobodyWidgets
//
//  Shared view primitives for vivobody widgets: compact stat strips,
//  heatmap cells, sparklines, and Liquid Glass wrappers. These keep
//  the four widget surfaces visually aligned without importing app UI.
//

import VivoKit
import Charts
import SwiftUI
import WidgetKit

struct WidgetStat: Identifiable, Hashable {
    var id: String { label }
    let value: String
    let unit: String?
    let label: String
    var accent: Bool = false

    init(value: String, unit: String? = nil, label: String, accent: Bool = false) {
        self.value = value
        self.unit = unit
        self.label = label
        self.accent = accent
    }
}

struct WidgetStatStrip: View {
    let stats: [WidgetStat]
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: compact ? Space.sm : Space.md) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(stat.value)
                            .font(compact ? Typography.metricInline : Typography.statValue)
                            .foregroundStyle(stat.accent ? Tint.primary : Ink.primary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let unit = stat.unit {
                            Text(unit)
                                .font(Typography.metricUnit)
                                .foregroundStyle(Ink.secondary)
                                .lineLimit(1)
                        }
                    }
                    Text(stat.label)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(stat.value)\(stat.unit.map { " \($0)" } ?? "") \(stat.label)")
            }
        }
    }
}

struct WidgetGlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .modifier(WidgetGlassPanelModifier())
    }
}

private struct WidgetGlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Surface.cardTint), in: .rect(cornerRadius: Radius.chip))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
    }
}

struct WidgetExerciseRows: View {
    let exercises: [UpNextExerciseSnapshot]
    let limit: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(exercises.prefix(limit)).indices, id: \.self) { index in
                let exercise = Array(exercises.prefix(limit))[index]
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text(exercise.name)
                        .font(Typography.headline)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: Space.sm)
                    Text(exercise.setSpec)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(minHeight: 28)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(exercise.name), \(exercise.setSpec)")

                if index < min(exercises.count, limit) - 1 {
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(height: 0.5)
                }
            }
        }
    }
}

struct ConsistencyHeatmapGrid: View {
    let weeks: [[ConsistencyDaySnapshot]]
    var cellSpacing: CGFloat = 3
    var cornerRadius: CGFloat = 2

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Grid(horizontalSpacing: cellSpacing, verticalSpacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { dayIndex in
                GridRow {
                    ForEach(weeks.indices, id: \.self) { weekIndex in
                        if weeks[weekIndex].indices.contains(dayIndex) {
                            cell(weeks[weekIndex][dayIndex])
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training heatmap")
    }

    private func cell(_ day: ConsistencyDaySnapshot) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(heatmapFill(day.level))
            .opacity(day.isInRange ? 1 : 0.28)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Ink.secondary, lineWidth: 1.2)
                }
            }
            .widgetAccentable(day.level > 0)
    }

    private func heatmapFill(_ level: Int) -> Color {
        if renderingMode == .vibrant {
            switch level {
            case 1: return .white.opacity(0.30)
            case 2: return .white.opacity(0.55)
            case 3: return .white.opacity(0.78)
            case 4: return .white
            default: return .white.opacity(0.10)
            }
        }

        switch level {
        case 1: return Tint.primary.opacity(0.30)
        case 2: return Tint.primary.opacity(0.55)
        case 3: return Tint.primary.opacity(0.78)
        case 4: return Tint.primary
        default: return Surface.cardTint
        }
    }
}

struct WeeklyVolumeSparkline: View {
    let values: [Int]

    var body: some View {
        let points = values.enumerated().map { WeeklyVolumePoint(week: $0.offset, sets: $0.element) }
        Chart(points) { point in
            AreaMark(
                x: .value("Week", point.week),
                y: .value("Sets", point.sets)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [Tint.primary.opacity(0.28), Tint.primary.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Week", point.week),
                y: .value("Sets", point.sets)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Tint.primary.opacity(Opacity.strong))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 48)
        .accessibilityLabel("Weekly volume trend")
    }
}

private struct WeeklyVolumePoint: Identifiable {
    var id: Int { week }
    let week: Int
    let sets: Int
}

struct HeatmapLegend: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: Space.sm) {
            Text("Less")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
            ForEach(0...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(fill(level))
                    .frame(width: 10, height: 10)
                    .widgetAccentable(level > 0)
                    .accessibilityHidden(true)
            }
            Text("More")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heatmap legend: less to more training")
    }

    private func fill(_ level: Int) -> Color {
        if renderingMode == .vibrant {
            return level == 0 ? .white.opacity(0.10) : .white.opacity([0.30, 0.55, 0.78, 1.0][level - 1])
        }
        switch level {
        case 1: return Tint.primary.opacity(0.30)
        case 2: return Tint.primary.opacity(0.55)
        case 3: return Tint.primary.opacity(0.78)
        case 4: return Tint.primary
        default: return Surface.cardTint
        }
    }
}

extension Double {
    var widgetOneDecimal: String {
        String(format: "%.1f", self)
    }
}

enum WidgetFormat {
    static var weightUnit: WidgetWeightUnit {
        let raw = UserDefaults(suiteName: WidgetShared.appGroup)?
            .string(forKey: WidgetShared.weightUnitKey) ?? WidgetWeightUnit.lb.rawValue
        return WidgetWeightUnit(rawValue: raw) ?? .lb
    }

    static func volumeValue(_ lb: Double) -> String {
        let display = SharedWeightFormatter.toDisplay(lb, unit: weightUnit)
        if display >= 10_000 {
            let k = display / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return NumberFormatter.widgetVolume.string(from: NSNumber(value: Int(display.rounded())))
            ?? "\(Int(display.rounded()))"
    }

    static var volumeUnit: String {
        weightUnit.symbol
    }
}

private extension NumberFormatter {
    static let widgetVolume: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
}
