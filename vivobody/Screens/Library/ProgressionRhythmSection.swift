//
//  ProgressionRhythmSection.swift
//  vivobody
//
//  Focused Exercise Detail load-cadence instrument. It renders the immutable
//  cadence presentation prepared by ExerciseDetailReadModel and owns only the
//  staircase motion and Pro cover.
//

import SwiftUI
import VivoKit

struct ExerciseDetailRhythmSection: View {
    let cadence: ExerciseDetailReadModel.Cadence?
    let now: Date
    let isUnlocked: Bool
    let onUnlock: () -> Void

    var body: some View {
        if let cadence {
            if isUnlocked {
                content(cadence)
            } else {
                LockedProCover(title: "Load cadence", action: onUnlock) {
                    content(cadence)
                }
            }
        }
    }

    private func content(
        _ cadence: ExerciseDetailReadModel.Cadence
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Load cadence")
                .sectionLabelStyle(Opacity.medium)
            ProgressionRhythmCard(cadence: cadence, now: now)
        }
    }
}

// MARK: - Card

private struct ProgressionRhythmCard: View {
    let cadence: ExerciseDetailReadModel.Cadence
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Space.xl) {
                    paceReadout
                    Spacer(minLength: Space.md)
                    currentReadout
                }

                VStack(alignment: .leading, spacing: Space.lg) {
                    paceReadout
                    currentReadout
                }
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text(cadence.showsRecentSubset ? "Recent load bests" : "Load bests")
                        .panelLegend()

                    Spacer(minLength: Space.sm)

                    Text(cadence.loadRangeText)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }

                ProgressionStaircase(
                    events: cadence.visibleEvents,
                    tailTint: statusTint,
                    now: now
                )

                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text(cadence.evidenceText)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)

                    Spacer(minLength: Space.sm)

                    Text("Today")
                        .panelLegend()
                }
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(bright: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cadence.accessibilityLabel)
    }

    private var paceReadout: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Usual pace")
                .panelLegend()

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(cadence.usualPaceText)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()

                Text(cadence.medianGapDays == 1 ? "day" : "days")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
                    .padding(.bottom, 3)
            }
        }
    }

    /// A separate live read prevents the historical median and the
    /// current cycle from collapsing into one ambiguous sentence.
    private var currentReadout: some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            Text("Current gap")
                .panelLegend()

            HStack(spacing: Space.sm) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusTint.opacity(0.35), radius: 4)
                    .accessibilityHidden(true)

                Text(cadence.currentGapText)
                    .font(Typography.metricInline)
                    .foregroundStyle(statusTint)
                    .monospacedDigit()
            }

            Text(cadence.currentDetailText)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statusTint: Color {
        cadence.daysSinceLastIncrease == 0 || cadence.isPastUsualRhythm
            ? Tint.complete
            : Ink.secondary
    }
}

// MARK: - Progression staircase

/// Time runs left-to-right while load rises bottom-to-top. Each
/// running-max event creates a literal step, so the graphic carries
/// its meaning without a separate tick-and-dot legend. History fades
/// from dim to bright toward now, a soft underglow grounds the line,
/// and the run since the last increase renders as a dotted lead-out
/// in the card's status tint so chart and Current readout agree. On
/// first appear the staircase traces itself in and the beads pop
/// into their sockets; Reduce Motion shows everything at rest.
private struct ProgressionStaircase: View {
    let events: [ExerciseDetailReadModel.LoadEvent]
    /// Tint for the dotted "since last increase" lead-out.
    var tailTint: Color = Tint.complete

    var now: Date = .init()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trace: CGFloat = 0
    @State private var tailTrace: CGFloat = 0
    @State private var beadsShown = false

    /// Keep enough turns to read as a rhythm without producing a
    /// dense sparkline on long-lived exercises.
    private static let inset: CGFloat = 7

    var body: some View {
        let units = Self.unitPoints(for: events, now: now)
        GeometryReader { geo in
            if units.count >= 2 {
                let points = scaledStairPoints(
                    units,
                    in: CGRect(origin: .zero, size: geo.size),
                    inset: Self.inset
                )
                ZStack {
                    StaircaseArea(unitPoints: units, inset: Self.inset)
                        .fill(
                            LinearGradient(
                                colors: [Ink.primary.opacity(0.10), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(trace)

                    StaircaseLine(unitPoints: units, inset: Self.inset)
                        .trim(from: 0, to: trace)
                        .stroke(
                            LinearGradient(
                                colors: [Ink.quaternary, Ink.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                    TailLine(unitPoints: units, inset: Self.inset)
                        .trim(from: 0, to: tailTrace)
                        .stroke(
                            tailTint.opacity(0.75),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 6])
                        )

                    // Sockets punch through line and underglow so each
                    // bead sits in a small gap instead of on the wire.
                    ForEach(points.indices, id: \.self) { index in
                        socket(at: index, points: points)
                    }

                    ForEach(points.indices, id: \.self) { index in
                        bead(at: index, points: points)
                    }
                }
                .compositingGroup()
            }
        }
        .frame(height: 72)
        .onAppear(perform: enter)
        .accessibilityHidden(true)
    }

    private func socket(at index: Int, points: [CGPoint]) -> some View {
        let isLatest = index == points.count - 1
        let diameter: CGFloat = isLatest ? 14 : 10
        return Circle()
            .fill(Color.black)
            .frame(width: diameter, height: diameter)
            .scaleEffect(beadsShown ? 1 : 0.2)
            .opacity(beadsShown ? 1 : 0)
            .blendMode(.destinationOut)
            .position(points[index])
            .animation(beadAnimation(index), value: beadsShown)
    }

    private func bead(at index: Int, points: [CGPoint]) -> some View {
        let count = points.count
        let isLatest = index == count - 1
        let diameter: CGFloat = isLatest ? 10 : 6
        let recency = count > 1 ? Double(index) / Double(count - 1) : 1
        return Circle()
            .fill(isLatest ? Tint.complete : Ink.primary.opacity(0.45 + 0.55 * recency))
            .frame(width: diameter, height: diameter)
            .shadow(color: isLatest ? Tint.complete.opacity(0.35) : .clear, radius: 4)
            .scaleEffect(beadsShown ? 1 : 0.2)
            .opacity(beadsShown ? 1 : 0)
            .position(points[index])
            .animation(beadAnimation(index), value: beadsShown)
    }

    private func beadAnimation(_ index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(response: 0.45, dampingFraction: 0.7)
            .delay(0.25 + Double(index) * 0.07)
    }

    private func enter() {
        guard trace == 0 else { return }
        if reduceMotion {
            trace = 1
            tailTrace = 1
            beadsShown = true
            return
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.95)) { trace = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9).delay(0.5)) { tailTrace = 1 }
        beadsShown = true
    }

    /// Normalize events into unit space: x is the fraction of the
    /// span from first event to now, y is the fraction of the load
    /// climb (0 at the bottom).
    private static func unitPoints(
        for events: [ExerciseDetailReadModel.LoadEvent],
        now: Date
    ) -> [CGPoint] {
        guard let first = events.first, let last = events.last else { return [] }
        let dateSpan = max(now.timeIntervalSince(first.date), 1)
        let loadSpan = max(last.load - first.load, 1)
        return events.map { event in
            CGPoint(
                x: min(max(event.date.timeIntervalSince(first.date) / dateSpan, 0), 1),
                y: min(max((event.load - first.load) / loadSpan, 0), 1)
            )
        }
    }
}

/// Scale unit-space stair points into a rect, honoring the drawing
/// inset. Shared by the shapes and the bead layout so every layer
/// lands on identical coordinates.
private nonisolated func scaledStairPoints(
    _ unitPoints: [CGPoint],
    in rect: CGRect,
    inset: CGFloat
) -> [CGPoint] {
    let width = max(1, rect.width - inset * 2)
    let height = max(1, rect.height - inset * 2)
    return unitPoints.map { unit in
        CGPoint(
            x: rect.minX + inset + width * unit.x,
            y: rect.minY + inset + height * (1 - unit.y)
        )
    }
}

/// The recorded history: baseline through the newest increase.
private struct StaircaseLine: Shape {
    let unitPoints: [CGPoint]
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = scaledStairPoints(unitPoints, in: rect, inset: inset)
        guard let start = points.first else { return path }
        path.move(to: start)
        for index in points.indices.dropFirst() {
            path.addLine(to: CGPoint(x: points[index].x, y: points[index - 1].y))
            path.addLine(to: points[index])
        }
        return path
    }
}

/// The run since the last increase: a flat lead-out from the newest
/// event to today's right edge.
private struct TailLine: Shape {
    let unitPoints: [CGPoint]
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = scaledStairPoints(unitPoints, in: rect, inset: inset)
        guard let last = points.last else { return path }
        path.move(to: last)
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: last.y))
        return path
    }
}

/// Region beneath the staircase (including the lead-out), for the
/// soft underglow fill.
private struct StaircaseArea: Shape {
    let unitPoints: [CGPoint]
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = scaledStairPoints(unitPoints, in: rect, inset: inset)
        guard let start = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: start.x, y: rect.maxY))
        path.addLine(to: start)
        for index in points.indices.dropFirst() {
            path.addLine(to: CGPoint(x: points[index].x, y: points[index - 1].y))
            path.addLine(to: points[index])
        }
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: last.y))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Load cadence") {
        let day: TimeInterval = 86400
        let now = Date()
        let cadence = ProgressionCadence(
            baseline: .init(date: now.addingTimeInterval(-64 * day), load: 135),
            increases: [
                .init(date: now.addingTimeInterval(-55 * day), load: 140),
                .init(date: now.addingTimeInterval(-46 * day), load: 145),
                .init(date: now.addingTimeInterval(-34 * day), load: 150),
                .init(date: now.addingTimeInterval(-27 * day), load: 155),
                .init(date: now.addingTimeInterval(-13 * day), load: 160),
            ],
            medianGapDays: 9,
            daysSinceLastIncrease: 13
        )
        let midCycle = ProgressionCadence(
            baseline: .init(date: now.addingTimeInterval(-40 * day), load: 95),
            increases: [
                .init(date: now.addingTimeInterval(-31 * day), load: 100),
                .init(date: now.addingTimeInterval(-22 * day), load: 105),
                .init(date: now.addingTimeInterval(-12 * day), load: 110),
                .init(date: now.addingTimeInterval(-4 * day), load: 115),
            ],
            medianGapDays: 9,
            daysSinceLastIncrease: 4
        )
        let cadencePresentation = ExerciseDetailReadModel.cadence(
            cadence,
            unit: .lb
        )
        let midCyclePresentation = ExerciseDetailReadModel.cadence(
            midCycle,
            unit: .lb
        )
        ScrollView {
            VStack(spacing: Space.xxl) {
                ExerciseDetailRhythmSection(
                    cadence: cadencePresentation,
                    now: now,
                    isUnlocked: true,
                    onUnlock: {}
                )
                ExerciseDetailRhythmSection(
                    cadence: midCyclePresentation,
                    now: now,
                    isUnlocked: true,
                    onUnlock: {}
                )
                ExerciseDetailRhythmSection(
                    cadence: cadencePresentation,
                    now: now,
                    isUnlocked: false,
                    onUnlock: {}
                )
            }
            .padding(Space.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
