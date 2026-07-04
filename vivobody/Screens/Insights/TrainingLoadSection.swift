//
//  TrainingLoadSection.swift
//  vivobody
//
//  The recovery lens: this week's training load weighed against the
//  last four weeks' habit (acute:chronic workload ratio, in tonnage).
//  A glance gauge marks where the ratio sits relative to the
//  productive 0.8–1.3 band and the 1.5 caution line, and one
//  plain-language line turns the number into a verdict — build, hold,
//  or back off.
//

import VivoKit
import SwiftUI

struct TrainingLoadSection: View {
    let report: TrainingLoadReport

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Training load", trailing: "7d vs 28d")

            if !report.hasEnoughHistory {
                Text(buildingCopy)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatStrip(
                    stats: [
                        Stat(value: WeightFormatter.volumeValue(report.acuteLoad, unit: unit), unit: unit.symbol, label: "This week"),
                        Stat(value: WeightFormatter.volumeValue(report.chronicWeekly, unit: unit), unit: unit.symbol, label: "4-wk avg"),
                        Stat(value: ratioLabel, label: "Load ratio", accent: report.verdict == .optimal),
                    ],
                    valueFont: Typography.statValue,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                insight

                LoadGauge(ratio: report.ratio, color: verdictColor)
                    .padding(.top, Space.xs)

                Text("Sweet spot 0.8–1.3   ·   caution above 1.5")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insight line

    private var insight: some View {
        Text(line)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Verdict word brightened against the dimmer explanation.
    private var line: AttributedString {
        var head = AttributedString(headline + " "); head.foregroundColor = Ink.primary
        var tail = AttributedString(explanation); tail.foregroundColor = Ink.secondary
        return head + tail
    }

    private var headline: String {
        switch report.verdict {
        case .detraining:   return "Load is easing."
        case .optimal:      return "Right in the build zone."
        case .pushing:      return "Ramping hard."
        case .overreaching: return "Load is spiking."
        case .insufficient: return ""
        }
    }

    private var explanation: String {
        switch report.verdict {
        case .detraining:
            return "This week sits below your 4-week baseline — fine for a deload, but stack a couple of full weeks to keep building."
        case .optimal:
            return "This week tracks your 4-week baseline closely. Keep stacking weeks like this and progress takes care of itself."
        case .pushing:
            return "This week runs well above your baseline. Strong push — guard sleep and joints before adding more."
        case .overreaching:
            return "This week is far above your 4-week baseline, where niggles and burnout creep in. Hold steady or back off for a week."
        case .insufficient:
            return ""
        }
    }

    private var buildingCopy: String {
        if report.daysLogged <= 0 {
            return "Once you've logged about three weeks, this reads your weekly load against your recent baseline to flag when you're ramping too fast."
        }
        let remaining = max(1, 21 - report.daysLogged)
        return "Building your load baseline — about \(remaining) more day\(remaining == 1 ? "" : "s") of history and this reads whether you're ramping too fast or coasting."
    }

    // MARK: - Derived

    private var ratioLabel: String {
        String(format: "%.2f", report.ratio)
    }

    private var verdictColor: Color {
        switch report.verdict {
        case .optimal, .pushing: return Tint.primary
        case .overreaching:      return Tint.danger
        case .detraining:        return Ink.secondary
        case .insufficient:      return Ink.tertiary
        }
    }
}

// MARK: - Load gauge

/// A single-axis gauge for the acute:chronic ratio, built from
/// discrete segments like a tuner dial. The track runs 0…2.0; the
/// productive 0.8–1.3 band wears a dim accent, the >1.5 caution zone
/// a dim red, and the segment at the current ratio is the one lit
/// lamp on the dial — the needle.
private struct LoadGauge: View {
    let ratio: Double
    let color: Color

    private let maxRatio: Double = 2.0
    private let segments = 40

    var body: some View {
        let needleIndex = needle
        return SegmentGauge(segments: segments, height: 10) { index, position in
            if index == needleIndex { return color }
            let r = position * maxRatio
            if r >= 0.8 && r <= 1.3 { return Tint.primary.opacity(0.22) }
            if r >= 1.5 { return Tint.danger.opacity(0.18) }
            return Surface.edge
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Load ratio \(String(format: "%.2f", ratio)) out of a sweet spot of 0.8 to 1.3"))
    }

    private var needle: Int {
        let clamped = min(max(ratio, 0), maxRatio)
        return min(segments - 1, Int(clamped / maxRatio * Double(segments)))
    }
}
