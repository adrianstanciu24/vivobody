//
//  DormantChart.swift
//  vivobody
//
//  Dormant-instrument placeholders for charts that cannot draw yet.
//  Instead of an error-styled empty box or invented sample data, the
//  placeholder keeps the live chart's chrome — the same card, hairline
//  grid, and micro axis type — and marks the slots future points will
//  occupy. Filled slots are real logged sessions (same orange glow as
//  a live chart's endpoint); the next empty slot breathes to show where
//  the next session lands. Text stays at legend level so the instrument
//  itself carries the meaning.
//
//  Three primitives:
//    • DormantSlotDot   — one point slot: filled, next (breathing), or
//      empty.
//    • DormantBaseline  — the flat dotted rule slots sit on. Dotted
//      means "structure, not data": a future x-axis, never a trend.
//    • DormantChartCard — the Load/Volume stand-in: full chart chrome
//      with zero or one real points plotted.
//    • DormantTrendSlots — the e1RM readiness instrument: required
//      workouts as slots, required day span as a hairline track.
//

import SwiftUI
import VivoKit

enum DormantSlotState {
    /// A real qualifying session — live-endpoint orange with its glow.
    case filled
    /// The slot the next session fills; breathes to pull the eye.
    case next
    /// A later requirement, still dormant.
    case empty
}

struct DormantSlotDot: View {
    let state: DormantSlotState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        Circle()
            .fill(state == .filled ? Tint.primary : Surface.cardTintBright)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(
                        state == .filled ? Tint.primary.opacity(0.75) : Surface.edgeBright,
                        lineWidth: 1
                    )
            }
            .shadow(
                color: state == .filled ? Tint.primary.opacity(0.58) : .clear,
                radius: 7
            )
            .opacity(state == .next && !breathing ? 0.45 : 1.0)
            .animation(
                state == .next && !reduceMotion
                    ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                    : nil,
                value: breathing
            )
            .onAppear {
                if state == .next { breathing = true }
            }
            .accessibilityHidden(true)
    }

    private var size: CGFloat {
        state == .filled ? 13 : 10
    }
}

/// The flat dotted rule dormant slots sit on. Never curves upward:
/// an ascending line would invent progress the user has not made.
struct DormantBaseline: View {
    var body: some View {
        DormantBaselineShape()
            .stroke(
                Ink.primary.opacity(0.16),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1.5, 5])
            )
            .frame(height: 2)
            .accessibilityHidden(true)
    }
}

private struct DormantBaselineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Load/Volume placeholder with the live chart's geometry: same card,
/// same 200pt canvas, same hairline grid. Zero sessions shows the first
/// slot breathing on an empty baseline; one session plots its real
/// point with the dotted baseline running out to the slot the next
/// session fills. Axis chrome is ghosted — a unit glyph and bare date
/// ticks, never invented numbers.
struct DormantChartCard: View {
    /// Micro legend at the card's top edge, e.g. "Trend unlocks at 2 sessions".
    let legend: String
    /// Ghost y-axis unit glyph ("lb" / "kg"); nil where units are ambiguous.
    let unitLabel: String?
    /// Formatted value of the single logged point, when exactly one
    /// session is in range. Non-nil plots that real point.
    let plottedValue: String?
    /// Whether the baseline runs out to a breathing "next session" slot.
    /// False when the gap is the selected range, not the logging habit.
    let showsNextSlot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(legend)
                .panelLegend()

            plotArea
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 200)
        .padding(Space.md)
        .contentCard()
    }

    private var plotArea: some View {
        VStack(spacing: 0) {
            gridRule(label: unitLabel)
            Spacer()
            gridRule(label: nil)
            Spacer()
            gridRule(label: nil)
            Spacer()
            slotBaseline
            ghostDateAxis
        }
    }

    private func gridRule(label: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let label {
                Text(label)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.quaternary)
            }
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var slotBaseline: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let plottedValue {
                Text(plottedValue)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
            }
            ZStack(alignment: .leading) {
                DormantBaseline()
                    .padding(.horizontal, 5)
                HStack(spacing: 0) {
                    DormantSlotDot(state: plottedValue == nil ? .next : .filled)
                    if plottedValue != nil, showsNextSlot {
                        Spacer()
                        DormantSlotDot(state: .next)
                    }
                }
            }
        }
    }

    /// Bare ticks where the live chart prints dates — axis chrome as
    /// silhouette, with no invented values.
    private var ghostDateAxis: some View {
        HStack {
            ghostDateTick
            Spacer()
            ghostDateTick
            Spacer()
            ghostDateTick
        }
        .padding(.top, 6)
        .accessibilityHidden(true)
    }

    private var ghostDateTick: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(width: 14, height: 1)
    }
}

/// The e1RM readiness instrument. Qualifying workouts fill slots on a
/// flat dormant baseline; the hairline track below fills toward the
/// required day span. Together they picture the "N workouts across M
/// days" rule in the legend above them, with no prose and no fake curve.
struct DormantTrendSlots: View {
    /// Qualifying workouts logged so far (0...slotCount).
    let filledSlots: Int
    /// Workouts required before the curve draws.
    let slotCount: Int
    /// Elapsed span toward the requirement, 0...1.
    let spanFraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            slotsRow
            spanTrack
        }
        .accessibilityHidden(true)
    }

    private var slotsRow: some View {
        ZStack(alignment: .leading) {
            DormantBaseline()
                .padding(.horizontal, 5)
            HStack(spacing: 0) {
                ForEach(0 ..< slotCount, id: \.self) { index in
                    if index > 0 { Spacer() }
                    DormantSlotDot(state: slotState(for: index))
                }
            }
        }
        .frame(height: 44)
    }

    private func slotState(for index: Int) -> DormantSlotState {
        if index < filledSlots { return .filled }
        return index == filledSlots ? .next : .empty
    }

    private var spanTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Surface.edge)
                Capsule()
                    .fill(Tint.primary)
                    .frame(width: max(0, min(1, spanFraction)) * proxy.size.width)
            }
        }
        .frame(height: 2)
    }
}

#Preview("Dormant charts") {
    ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 20) {
                DormantChartCard(
                    legend: "Trend unlocks at 2 sessions",
                    unitLabel: "lb",
                    plottedValue: nil,
                    showsNextSlot: true
                )
                DormantChartCard(
                    legend: "One more session draws the line",
                    unitLabel: "lb",
                    plottedValue: "135 lb",
                    showsNextSlot: true
                )
                DormantTrendSlots(filledSlots: 1, slotCount: 4, spanFraction: 0)
                    .padding(Space.xl)
                    .contentCard()
                DormantTrendSlots(filledSlots: 4, slotCount: 4, spanFraction: 0.5)
                    .padding(Space.xl)
                    .contentCard()
            }
            .padding(Space.xxl)
        }
    }
    .preferredColorScheme(.dark)
}
