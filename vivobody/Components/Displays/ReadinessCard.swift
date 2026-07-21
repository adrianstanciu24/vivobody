//
//  ReadinessCard.swift
//  vivobody
//
//  The Today tab's readiness section card, drawn instead of spoken:
//  a labelled seven-day activity strip (one bar per weekday, sized by
//  that day's estimated hard-set load, today lit in the verdict
//  colour) over the personal load-range gauge from Insights (marker
//  against the productive band, Low / Productive / High legend).
//  The ReadinessLine sentence the card replaced lives on as its
//  VoiceOver label. Before the personal range has formed the gauge
//  shows a provisional marker from the active prior weeks available.
//

import VivoKit
import SwiftUI

struct ReadinessCard: View {
    let report: TrainingLoadReport
    let line: ReadinessLine

    var body: some View {
        VStack(spacing: Space.lg) {
            dayStrip
            rangeGauge
        }
        .padding(Space.xl)
        .contentCard()
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(line.phrase)
    }

    /// Dim trailing note for the section header — the verdict the
    /// gauge marker is showing, or that the range is still forming.
    static func statusText(for report: TrainingLoadReport) -> String? {
        switch report.verdict {
        case .insufficient: return "Building range"
        case .low:          return "Low load"
        case .productive:   return "Productive load"
        case .high:         return "High load"
        }
    }

    /// The verdict's ink, shared with the training-load decoder sheet
    /// so today's bar, the gauge marker, and the sheet's status dot
    /// always agree.
    static func statusColor(for report: TrainingLoadReport) -> Color {
        switch report.verdict {
        case .productive:   return Tint.primary
        case .high:         return Tint.primary
        case .low:          return Ink.secondary
        case .insufficient: return Ink.primary
        }
    }

    /// Segment ink for the personal load-range gauge: the lit marker
    /// (provisional markers stay tinted while the range forms), the
    /// productive band, or the unlit track. Shared with the decoder
    /// sheet so both gauges read identically.
    static func gaugeSegmentColor(at position: Double, for report: TrainingLoadReport) -> Color {
        if let marker = report.gaugeMarkerPosition, abs(position - marker) < 0.025 {
            return report.hasEnoughHistory ? statusColor(for: report) : Tint.primary
        }
        if TrainingLoadReport.gaugeProductiveBand.contains(position) {
            return Tint.primary.opacity(0.28)
        }
        return Surface.edge
    }

    // MARK: - Seven-day strip

    private static let stripHeight: CGFloat = 34
    private static let barWidth: CGFloat = 18
    private static let restTickHeight: CGFloat = 3

    /// One column per trailing calendar day, oldest left, today
    /// right: a bar sized by that day's load (rest days sit as dim
    /// baseline ticks) over the weekday initial. Today wears the
    /// verdict colour.
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

                    Text(day.weekdayInitial())
                        .font(Typography.metricMicro)
                        .foregroundStyle(isToday ? Ink.secondary : Ink.quaternary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(_ load: Double, peak: Double) -> CGFloat {
        guard load > 0 else { return Self.restTickHeight }
        return max(8, Self.stripHeight * CGFloat(load / peak))
    }

    private func barColor(trained: Bool, isToday: Bool) -> Color {
        if isToday {
            return trained ? Self.statusColor(for: report) : Ink.quaternary
        }
        return trained ? Ink.tertiary : Surface.edge
    }

    // MARK: - Personal range gauge

    /// The Insights load gauge: the tinted band is the personal
    /// productive range, the lit segment is where the rolling week
    /// sits right now, decoded by the legend beneath.
    private var rangeGauge: some View {
        VStack(spacing: Space.sm) {
            SegmentGauge(segments: 48, height: 8, spacing: 2) { _, position in
                Self.gaugeSegmentColor(at: position, for: report)
            }

            HStack {
                Text("Low")
                Spacer()
                Text("Productive")
                Spacer()
                Text("High")
            }
            .panelLegend()
        }
        .accessibilityHidden(true)
    }
}
