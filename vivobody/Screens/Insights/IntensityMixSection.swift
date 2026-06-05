//
//  IntensityMixSection.swift
//  vivobody
//
//  The rep-range distribution of your working sets over the last four
//  weeks: how much sits in the heavy strength range (1–5), the
//  growth/hypertrophy range (6–12), and the higher-rep endurance
//  range (13+). A single segmented bar shows the split; a legend
//  names the counts; one line reads the emphasis and nudges the gap.
//
//  Hypertrophy wears the accent as the productive default zone; the
//  heavy and high-rep ends sit in grayscale luminance — one accent,
//  hierarchy by brightness, like the rest of the app.
//

import SwiftUI

struct IntensityMixSection: View {
    let mix: IntensityMix

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Intensity", trailing: "last 4 weeks")

            if !mix.hasData {
                Text("As you log weighted sets, this splits them across the strength, hypertrophy, and endurance rep ranges so you can see what your training really emphasises.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                insight

                SegmentBar(segments: segments)
                    .padding(.top, Space.xs)

                VStack(spacing: Space.md) {
                    ForEach(IntensityZone.allCases, id: \.self) { zone in
                        legendRow(zone)
                    }
                }
                .padding(.top, Space.xs)
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

    private var line: AttributedString {
        guard let dominant = mix.dominant else {
            return AttributedString("")
        }
        let pct = Int((mix.share(dominant) * 100).rounded())

        // Balanced read when no single zone owns a clear majority.
        if mix.share(dominant) < 0.5 {
            var a = AttributedString("A balanced spread"); a.foregroundColor = Ink.primary
            var b = AttributedString(" across rep ranges — heavy, hypertrophy, and higher-rep work all represented.")
            b.foregroundColor = Ink.secondary
            return a + b
        }

        var lead = AttributedString("\(pct)% "); lead.foregroundColor = Ink.primary
        var mid = AttributedString("of your sets are "); mid.foregroundColor = Ink.secondary
        var zoneName = AttributedString("\(dominant.label.lowercased()) work (\(dominant.repRange))")
        zoneName.foregroundColor = Ink.primary
        var nudge = AttributedString(". " + advice(for: dominant)); nudge.foregroundColor = Ink.secondary
        return lead + mid + zoneName + nudge
    }

    private func advice(for zone: IntensityZone) -> String {
        switch zone {
        case .strength:
            return "Heavy and neural — fold in some 6–12 work to add size to the strength."
        case .hypertrophy:
            return mix.share(.strength) < 0.15
                ? "Squarely in the growth zone — add a little heavy 1–5 work to keep driving your e1RM."
                : "Squarely in the growth zone, with heavy work backing it up."
        case .endurance:
            return "High-rep and metabolic — drop the reps and add load to drive strength and size."
        }
    }

    // MARK: - Legend

    private func legendRow(_ zone: IntensityZone) -> some View {
        let count = mix.count(zone)
        let pct = Int((mix.share(zone) * 100).rounded())
        return HStack(spacing: Space.sm) {
            Circle()
                .fill(color(zone))
                .frame(width: 8, height: 8)
            Text(zone.label)
                .font(Typography.body)
                .foregroundStyle(Ink.primary)
            Text(zone.repRange)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
            Spacer(minLength: Space.sm)
            Text("\(count) \(count == 1 ? "set" : "sets")")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Ink.secondary)
                .monospacedDigit()
            Text("\(pct)%")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(zone == mix.dominant ? Tint.primary : Ink.tertiary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Derived

    private var segments: [SegmentBar.Segment] {
        IntensityZone.allCases.compactMap { zone in
            let share = mix.share(zone)
            guard share > 0 else { return nil }
            return SegmentBar.Segment(share: share, color: color(zone))
        }
    }

    private func color(_ zone: IntensityZone) -> Color {
        switch zone {
        case .strength:    return Ink.secondary
        case .hypertrophy: return Tint.primary
        case .endurance:   return Ink.quaternary
        }
    }
}

// MARK: - Segmented bar

/// A horizontal bar split into proportional segments with a hairline
/// gap between each — the rep-range distribution at a glance.
private struct SegmentBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let share: Double
        let color: Color
    }

    let segments: [Segment]

    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let avail = geo.size.width - gap * CGFloat(max(0, segments.count - 1))
            HStack(spacing: gap) {
                ForEach(segments) { segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: max(2, avail * segment.share))
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
