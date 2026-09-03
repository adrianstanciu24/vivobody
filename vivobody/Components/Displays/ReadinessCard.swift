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
    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    static let scopeText = "Last 7 days"

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            verdict
            loadReadout
            rangeGauge

            if let loadCoverageNote {
                Text(loadCoverageNote)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
        .accessibilityValue(Self.accessibilityValue(for: report, line: line, unit: unit))
    }

    // MARK: - Shared container contract

    /// Exact semantics for the parent navigation button. The visual card
    /// is deliberately one focus stop, so its current value, comparison,
    /// scope, and secondary daily receipt all live in this value.
    static func accessibilityValue(
        for report: TrainingLoadReport,
        line: ReadinessLine,
        unit: WeightUnit
    ) -> String {
        var parts = [
            "\(verdictText(for: report)).",
            "Current load: \(spokenCurrentMeasure(report, unit: unit)) in the rolling last 7 calendar days.",
        ]

        if let usual = report.usualLoad,
           let range = report.recentRange
        {
            parts.append(
                "Your usual load is \(spokenMeasure(usual, report: report, unit: unit)) per week, based on the median of the four preceding weeks."
            )
            switch report.measure {
            case .volumeLoad:
                parts.append(
                    "Your recent range is \(spokenMeasure(range.lowerBound, report: report, unit: unit)) to \(spokenMeasure(range.upperBound, report: report, unit: unit))."
                )
            case .hardSets:
                parts.append(
                    "Your recent range is \(formatLoad(range.lowerBound)) to \(formatLoad(range.upperBound)) estimated hard sets."
                )
            }
        } else if report.gaugeMarkerPosition != nil {
            parts.append(
                "Your stable usual load and recent range are still forming. The current marker is provisional and compares with active prior weeks."
            )
        } else {
            parts.append(
                "Your stable usual load and recent range are not available yet."
            )
        }

        if let coverage = loadCoverageNote(for: report, unit: unit) {
            parts.append(coverage)
        }
        parts.append(line.phrase)
        if let history = dailyHistoryAccessibilityText(for: report, unit: unit) {
            parts.append(history)
        }
        return parts.joined(separator: " ")
    }

    /// Compatibility used by Today while its container owns the section heading.
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
                stackedLoadReadout
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: Space.xl) {
                        currentMetric
                        Spacer(minLength: Space.sm)
                        usualMetric
                    }
                    stackedLoadReadout
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var stackedLoadReadout: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            currentMetric
            SectionDivider()
            usualMetric
        }
    }

    private var currentMetric: some View {
        loadMetric(
            value: currentMeasureValue,
            unit: currentMeasureUnit,
            label: currentMetricLabel,
            font: Typography.metricLg,
            color: Tint.primaryText
        )
    }

    private var usualMetric: some View {
        loadMetric(
            value: report.usualLoad.map(formatMeasureValue) ?? "Forming",
            unit: report.measure == .volumeLoad && report.usualLoad != nil ? unit.symbol : nil,
            label: usualMetricLabel,
            font: report.usualLoad == nil ? Typography.title : Typography.statValueCompact,
            color: Ink.primary
        )
    }

    private var currentMetricLabel: String {
        switch report.measure {
        case .volumeLoad: "Volume load · last 7 days"
        case .hardSets: "Current · last 7 days"
        }
    }

    private var currentMeasureValue: String {
        formatMeasureValue(report.currentLoad)
    }

    private var currentMeasureUnit: String? {
        report.measure == .volumeLoad ? unit.symbol : nil
    }

    private var usualMetricLabel: String {
        switch report.measure {
        case .volumeLoad: "Your usual · volume load"
        case .hardSets: "Your usual · est. hard sets"
        }
    }

    private func loadMetric(
        value: String,
        unit: String? = nil,
        label: String,
        font: Font,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(font)
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
                if let unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
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
                    Text(recentRangeLabel)
                        .panelLegend()
                    Spacer(minLength: Space.sm)
                    rangeValue
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(recentRangeLabel)
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

    private var recentRangeLabel: String {
        switch report.measure {
        case .volumeLoad: "Your recent range · volume load"
        case .hardSets: "Your recent range · est. hard sets"
        }
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
                Text("Usual \(formatMeasure(usual))")
                Spacer(minLength: Space.sm)
                Text("\(formatMeasure(usual * 2)) · 2×")
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
        report.recentRange.map { range in
            switch report.measure {
            case .volumeLoad:
                "\(WeightFormatter.volumeValue(range.lowerBound, unit: unit))–\(WeightFormatter.volumeValue(range.upperBound, unit: unit)) \(unit.symbol)"
            case .hardSets:
                "\(Self.formatLoad(range.lowerBound))–\(Self.formatLoad(range.upperBound))"
            }
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
            return "Scale from 0 to \(Self.spokenMeasure(usual * 2, report: report, unit: unit)); your usual is \(Self.spokenMeasure(usual, report: report, unit: unit))."
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

    private func formatMeasure(_ value: Double) -> String {
        switch report.measure {
        case .volumeLoad: WeightFormatter.volumeString(value, unit: unit)
        case .hardSets: Self.formatLoad(value)
        }
    }

    private func formatMeasureValue(_ value: Double) -> String {
        switch report.measure {
        case .volumeLoad: WeightFormatter.volumeValue(value, unit: unit)
        case .hardSets: Self.formatLoad(value)
        }
    }

    private static func spokenMeasure(
        _ value: Double,
        report: TrainingLoadReport,
        unit: WeightUnit
    ) -> String {
        switch report.measure {
        case .volumeLoad:
            "\(WeightFormatter.fullVolumeValue(value, unit: unit)) \(unit.displayName.lowercased()) of volume load"
        case .hardSets:
            "\(formatLoad(value)) estimated hard sets"
        }
    }

    private static func spokenCurrentMeasure(
        _ report: TrainingLoadReport,
        unit: WeightUnit
    ) -> String {
        spokenMeasure(report.currentLoad, report: report, unit: unit)
    }

    private static func dailyHistoryAccessibilityText(
        for report: TrainingLoadReport,
        unit: WeightUnit
    ) -> String? {
        guard !report.recentDays.isEmpty else { return nil }
        let lastID = report.recentDays.last?.id
        let readings = report.recentDays.map { day in
            let name = day.id == lastID
                ? "Today"
                : day.date.formatted(.dateTime.weekday(.wide))
            let value: String = if day.trained,
                                   day.load == 0,
                                   report.measure == .volumeLoad,
                                   report.loadAvailability != .complete
            {
                "\(WeightFormatter.fullVolumeValue(0, unit: unit)) known \(unit.displayName.lowercased()) of volume load"
            } else if day.trained {
                spokenMeasure(day.load, report: report, unit: unit)
            } else {
                "rest"
            }
            return "\(name), \(value)"
        }
        return "Daily history: \(readings.joined(separator: "; "))."
    }

    private static func loadCoverageNote(
        for report: TrainingLoadReport,
        unit: WeightUnit
    ) -> String? {
        guard report.measure == .volumeLoad else { return nil }
        switch report.loadAvailability {
        case .complete: return nil
        case .partial:
            return "Some sets have no comparable load, so this reading includes only known load."
        case .unavailable:
            return "Current sets have no comparable load, so this week's known subtotal is \(WeightFormatter.volumeString(0, unit: unit))."
        }
    }

    private var loadCoverageNote: String? {
        Self.loadCoverageNote(for: report, unit: unit)
    }
}
