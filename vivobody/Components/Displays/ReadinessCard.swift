//
//  ReadinessCard.swift
//  vivobody
//
//  Today's compact Training Load instrument. A large qualitative read
//  leads a continuous current-versus-usual gauge: the rolling seven-day
//  load has one labelled marker, the user's recent range has explicit
//  bounds, and the shared scale stays truthful while that range forms.
//  The seven daily bars are a secondary receipt, never the headline.
//

import SwiftUI
import VivoKit

struct ReadinessCard: View {
    let report: TrainingLoadReport
    let line: ReadinessLine

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static let scopeText = "Last 7 days"

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            verdict
            loadReadout
            rangeGauge

            if !report.recentDays.isEmpty {
                SectionDivider()
                recentHistory
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(bright: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training load")
        .accessibilityValue(Self.accessibilityValue(for: report, line: line))
    }

    // MARK: - Shared container contract

    /// Exact semantics for the parent navigation button. The visual card
    /// is deliberately one focus stop, so its current value, comparison,
    /// scope, and secondary daily receipt all live in this value.
    static func accessibilityValue(
        for report: TrainingLoadReport,
        line: ReadinessLine
    ) -> String {
        var parts = [
            "\(verdictText(for: report)).",
            "Current load: \(formatLoad(report.currentLoad)) estimated hard sets in the rolling last 7 calendar days.",
        ]

        if let usual = report.usualLoad,
           let range = report.recentRange
        {
            parts.append(
                "Your usual load is \(formatLoad(usual)) estimated hard sets per week, based on the median of the four preceding weeks."
            )
            parts.append(
                "Your recent range is \(formatLoad(range.lowerBound)) to \(formatLoad(range.upperBound)) estimated hard sets."
            )
        } else if report.gaugeMarkerPosition != nil {
            parts.append(
                "Your stable usual load and recent range are still forming. The current marker is provisional and compares with active prior weeks."
            )
        } else {
            parts.append(
                "Your stable usual load and recent range are not available yet."
            )
        }

        parts.append(line.phrase)
        if let history = dailyHistoryAccessibilityText(for: report) {
            parts.append(history)
        }
        return parts.joined(separator: " ")
    }

    /// Compatibility used by Today while its container owns the section
    /// heading. New layouts should show `scopeText` there and let the card
    /// own this verdict instead of repeating it.
    static func statusText(for report: TrainingLoadReport) -> String? {
        switch report.verdict {
        case .insufficient: "Range forming"
        case .low: "Below range"
        case .productive: "Within range"
        case .high: "Above range"
        }
    }

    /// The verdict's graphical ink, shared with the training-load decoder.
    static func statusColor(for report: TrainingLoadReport) -> Color {
        switch report.verdict {
        case .productive: Tint.primary
        case .high: Tint.primary
        case .low: Ink.secondary
        case .insufficient: Ink.primary
        }
    }

    /// Compatibility for the decoder sheet's existing segmented gauge.
    /// Today's card uses the continuous, explicitly labelled scale below.
    static func gaugeSegmentColor(at position: Double, for report: TrainingLoadReport) -> Color {
        if let marker = report.gaugeMarkerPosition, abs(position - marker) < 0.025 {
            return report.hasEnoughHistory ? statusColor(for: report) : Tint.primary
        }
        if TrainingLoadReport.gaugeProductiveBand.contains(position) {
            return Tint.primary.opacity(0.28)
        }
        return Surface.edge
    }

    // MARK: - Glance

    private var verdict: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(Self.verdictText(for: report))
                .font(Typography.display)
                .foregroundStyle(verdictTextColor)
                .fixedSize(horizontal: false, vertical: true)

            Text(line.phrase)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loadReadout: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.md) {
                    currentMetric
                    SectionDivider()
                    usualMetric
                }
            } else {
                HStack(alignment: .bottom, spacing: Space.xl) {
                    currentMetric
                    Spacer(minLength: Space.sm)
                    usualMetric
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var currentMetric: some View {
        loadMetric(
            value: Self.formatLoad(report.currentLoad),
            label: "Current · last 7 days",
            font: Typography.metricLg,
            color: Tint.primaryText
        )
    }

    private var usualMetric: some View {
        loadMetric(
            value: report.usualLoad.map(Self.formatLoad) ?? "Forming",
            label: "Your usual · est. hard sets",
            font: report.usualLoad == nil ? Typography.title : Typography.statValueCompact,
            color: Ink.primary
        )
    }

    private func loadMetric(
        value: String,
        label: String,
        font: Font,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(value)
                .font(font)
                .foregroundStyle(color)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text(label)
                .panelLegend()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Current versus recent range

    private var rangeGauge: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text("Your recent range · est. hard sets")
                        .panelLegend()
                    Spacer(minLength: Space.sm)
                    rangeValue
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Your recent range · est. hard sets")
                        .panelLegend()
                    rangeValue
                }
            }

            gaugeTrack
            gaugeAxis
        }
        .accessibilityHidden(true)
    }

    private var rangeValue: some View {
        Text(formattedRange ?? "Forming")
            .font(formattedRange == nil ? Typography.sectionHeading : Typography.metricInline)
            .foregroundStyle(formattedRange == nil ? Ink.secondary : Ink.primary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    private var gaugeTrack: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let band = TrainingLoadReport.gaugeRecentBand
            let bandStart = width * CGFloat(band.lowerBound)
            let bandWidth = width * CGFloat(band.upperBound - band.lowerBound)
            let accessibleGauge = dynamicTypeSize.isAccessibilitySize
            let trackY: CGFloat = accessibleGauge ? 47 : 31
            let labelY: CGFloat = accessibleGauge ? 15 : 7
            let labelWidth: CGFloat = accessibleGauge ? 120 : 100

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Surface.edge)
                    .frame(width: width, height: 18)
                    .position(x: width / 2, y: trackY)

                if report.hasEnoughHistory || report.gaugeMarkerPosition != nil {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(rangeBandFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(rangeBandOutline, lineWidth: 1.5)
                        }
                        .frame(width: bandWidth, height: 18)
                        .position(x: bandStart + bandWidth / 2, y: trackY)
                }

                if report.hasEnoughHistory {
                    Rectangle()
                        .fill(Ink.secondary)
                        .frame(width: 2, height: 26)
                        .position(x: width / 2, y: trackY)
                }

                if let position = report.gaugeMarkerPosition {
                    let markerX = min(width - 9, max(9, width * CGFloat(position)))
                    let labelMargin = labelWidth / 2
                    let labelX = min(width - labelMargin, max(labelMargin, markerX))

                    Text(markerLabel)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Tint.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(width: labelWidth)
                        .position(x: labelX, y: labelY)

                    Capsule()
                        .fill(Ink.primary)
                        .frame(width: 4, height: 28)
                        .position(x: markerX, y: trackY)

                    ZStack {
                        Circle()
                            .fill(Ink.primary)
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(Tint.primary)
                            .frame(width: 8, height: 8)
                    }
                    .position(x: markerX, y: trackY)
                }
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 62 : 46)
    }

    @ViewBuilder
    private var gaugeAxis: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(accessibleAxisText)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let usual = report.usualLoad {
            HStack(spacing: Space.sm) {
                Text("0")
                Spacer(minLength: Space.sm)
                Text("Usual \(Self.formatLoad(usual))")
                Spacer(minLength: Space.sm)
                Text("\(Self.formatLoad(usual * 2)) · 2×")
            }
            .panelLegend()
        } else if report.gaugeMarkerPosition != nil {
            HStack(spacing: Space.sm) {
                Text("Lower")
                Spacer(minLength: Space.sm)
                Text("Early comparison")
                Spacer(minLength: Space.sm)
                Text("Higher")
            }
            .panelLegend()
        } else {
            Text("Comparison position appears after a prior active week")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formattedRange: String? {
        report.recentRange.map {
            "\(Self.formatLoad($0.lowerBound))–\(Self.formatLoad($0.upperBound))"
        }
    }

    private var markerLabel: String {
        guard let ratio = report.gaugeRatio,
              ratio > TrainingLoadReport.gaugeRatioSpan
        else { return "CURRENT" }
        return "CURRENT · 2×+"
    }

    private var accessibleAxisText: String {
        if let usual = report.usualLoad {
            return "Scale from 0 to \(Self.formatLoad(usual * 2)) estimated hard sets; your usual is \(Self.formatLoad(usual))."
        }
        if report.gaugeMarkerPosition != nil {
            return "Early relative comparison while your personal range forms."
        }
        return "A comparison position appears after a prior active week."
    }

    private var rangeBandFill: Color {
        report.hasEnoughHistory ? Tint.primary.opacity(0.24) : Ink.quaternary.opacity(0.18)
    }

    private var rangeBandOutline: Color {
        report.hasEnoughHistory ? Tint.primaryText : Ink.tertiary
    }

    // MARK: - Secondary seven-day receipt

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily history")
                    .panelLegend()
                Spacer(minLength: Space.sm)
                Text(Self.scopeText)
                    .panelLegend()
            }
            dayStrip
        }
        .accessibilityHidden(true)
    }

    private static let stripHeight: CGFloat = 30
    private static let barWidth: CGFloat = 16
    private static let restTickHeight: CGFloat = 3

    private var dayStrip: some View {
        let peak = max(report.recentDays.map(\.load).max() ?? 0, 1)
        return HStack(spacing: Space.sm) {
            ForEach(report.recentDays) { day in
                let isToday = day.id == report.recentDays.last?.id
                VStack(spacing: Space.xs) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(barColor(trained: day.trained, isToday: isToday))
                            .frame(
                                width: Self.barWidth,
                                height: barHeight(day.load, peak: peak)
                            )
                    }
                    .frame(height: Self.stripHeight)

                    Text(dayLabel(for: day, isToday: isToday))
                        .font(Typography.metricMicro)
                        .foregroundStyle(isToday ? Tint.primaryText : Ink.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(_ load: Double, peak: Double) -> CGFloat {
        guard load > 0 else { return Self.restTickHeight }
        return max(8, Self.stripHeight * CGFloat(load / peak))
    }

    private func barColor(trained: Bool, isToday: Bool) -> Color {
        if isToday {
            return trained ? Tint.primary : Ink.quaternary
        }
        return trained ? Ink.tertiary : Surface.edge
    }

    /// Seven equal columns cannot hold a scaled word at Accessibility sizes.
    /// The orange ink still marks today visually, while the container's exact
    /// accessibility value names every date and reading in full.
    private func dayLabel(for day: DayLoad, isToday: Bool) -> String {
        isToday && !dynamicTypeSize.isAccessibilitySize
            ? "Now"
            : day.weekdayInitial()
    }

    // MARK: - Copy and formatting

    private static func verdictText(for report: TrainingLoadReport) -> String {
        switch report.verdict {
        case .low: "Below your range"
        case .productive: "Within your range"
        case .high: "Above your range"
        case .insufficient: "Range still forming"
        }
    }

    private var verdictTextColor: Color {
        report.verdict == .productive ? Tint.primaryText : Ink.primary
    }

    private static func formatLoad(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private static func dailyHistoryAccessibilityText(
        for report: TrainingLoadReport
    ) -> String? {
        guard !report.recentDays.isEmpty else { return nil }
        let lastID = report.recentDays.last?.id
        let readings = report.recentDays.map { day in
            let name = day.id == lastID
                ? "Today"
                : day.date.formatted(.dateTime.weekday(.wide))
            let value = day.trained
                ? "\(formatLoad(day.load)) estimated hard sets"
                : "rest"
            return "\(name), \(value)"
        }
        return "Daily history: \(readings.joined(separator: "; "))."
    }
}
