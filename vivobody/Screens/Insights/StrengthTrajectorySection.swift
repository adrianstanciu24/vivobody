//
//  StrengthTrajectorySection.swift
//  vivobody
//
//  Strength as a real curve, not a bar. The muscle sections read the
//  development model; this asks the other question — is the LOAD on
//  the bar going up? — and answers it the way a lifter actually wants
//  to see: an estimated-1RM line over time, with the all-time best
//  drawn as a record line to chase and each new PR marked on the
//  curve. A lift selector swaps which exercise is in focus.
//
//  e1RM (Epley) is charted rather than raw top weight so a 5×5 and an
//  8×3 sit on one comparable strength axis. Data comes from
//  `progressByExercise` (the same series the Me tab charts); the
//  trend, PR projection, and ordering come from `strengthOutlook`.
//

import SwiftUI
import Charts

struct StrengthTrajectorySection: View {
    let board: StrengthOutlookBoard
    let progress: [ExerciseProgress]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Nil falls back to the board's lead lift (climbing first).
    @State private var chosen: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Strength", trailing: "estimated 1RM")

            if !board.hasAny {
                Text("Strength trends appear once you've logged a weighted lift across a few sessions.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatStrip(
                    stats: [
                        Stat(value: "\(board.climbingCount)", label: "Climbing", accent: board.climbingCount > 0),
                        Stat(value: "\(board.plateauedCount)", label: "Stalled"),
                        Stat(value: "\(board.slippingCount)", label: "Slipping"),
                    ],
                    valueFont: Typography.statValue,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                insight

                selector

                if let stat = currentStat {
                    chart(for: stat)
                    liftStats(stat)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insight

    @ViewBuilder
    private var insight: some View {
        if let pr = board.nearestPR {
            if pr.isFreshPR {
                Text(line(name: pr.exercise, lead: "New PR on ", tail: " — ride the momentum."))
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let days = pr.daysToPR {
                Text(line(name: pr.exercise, lead: "Closest PR: ", tail: " — about \(etaPhrase(days)) out at this rate."))
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(line(name: pr.exercise, lead: "", tail: " is climbing back toward its best."))
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let stalled = board.stats.first(where: { $0.trend == .plateaued }) {
            let tail = stalled.weeksSinceBest.map { " has stalled — \($0)w since its last PR. Time to change a variable." } ?? " has stalled. Time to change a variable."
            Text(line(name: stalled.exercise, lead: "", tail: tail))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else if let slip = board.stats.first(where: { $0.trend == .slipping }) {
            Text(line(name: slip.exercise, lead: "", tail: " is sliding — re-groove the movement before adding load."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func line(name: String, lead: String, tail: String) -> AttributedString {
        var head = AttributedString(lead); head.foregroundColor = Ink.secondary
        var lift = AttributedString(name); lift.foregroundColor = Ink.primary
        var rest = AttributedString(tail); rest.foregroundColor = Ink.secondary
        return head + lift + rest
    }

    // MARK: - Lift selector

    private var selector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(board.stats) { stat in
                    chip(stat)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func chip(_ stat: StrengthOutlookStat) -> some View {
        let isSelected = stat.exercise == currentName
        return Button {
            Haptics.selection()
            chosen = stat.exercise
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(prColor(stat.trend))
                    .frame(width: 6, height: 6)
                Text(stat.exercise)
                    .font(Typography.sectionLabel)
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(
                Capsule().fill(isSelected ? Tint.primary : Surface.cardTint)
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Surface.edgeBright : Surface.edge,
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart

    private func chart(for stat: StrengthOutlookStat) -> some View {
        let points = e1rmSeries(for: stat.exercise)
        let color = prColor(stat.trend)
        let best = WeightFormatter.toDisplay(stat.bestE1RM, unit: unit)

        return Chart {
            RuleMark(y: .value("Best", best))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Tint.primary.opacity(0.5))
                .annotation(position: .top, alignment: .trailing) {
                    Text("best")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Tint.primary.opacity(0.8))
                }

            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(color)

                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if p.isPR {
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("e1RM", p.value)
                    )
                    .symbolSize(50)
                    .foregroundStyle(Tint.primary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(height: 200)
        .padding(.top, Space.sm)
    }

    private func liftStats(_ stat: StrengthOutlookStat) -> some View {
        StatStrip(
            stats: [
                Stat(value: WeightFormatter.string(stat.currentE1RM, unit: unit, includeUnit: false), unit: unit.symbol, label: "Current e1RM"),
                Stat(value: WeightFormatter.string(stat.bestE1RM, unit: unit, includeUnit: false), unit: unit.symbol, label: "Best"),
                Stat(value: prLabel(stat), label: "Trend"),
            ],
            valueFont: Typography.statValue,
            edgeAligned: true
        )
        .padding(.top, Space.xs)
    }

    // MARK: - Derived

    private var currentName: String { chosen ?? board.stats.first?.exercise ?? "" }
    private var currentStat: StrengthOutlookStat? { board.stat(for: currentName) ?? board.stats.first }

    /// e1RM points (display units) for one lift, each flagged when it
    /// set a new estimated-1RM record at the moment it was logged.
    private func e1rmSeries(for exercise: String) -> [E1RMPoint] {
        guard let series = progress.first(where: { $0.name.caseInsensitiveCompare(exercise) == .orderedSame }) else {
            return []
        }
        var runningMax = -Double.infinity
        var out: [E1RMPoint] = []
        for point in series.points where point.estimated1RM > 0 {
            let isPR = point.estimated1RM > runningMax
            if isPR { runningMax = point.estimated1RM }
            out.append(
                E1RMPoint(
                    date: point.date,
                    value: WeightFormatter.toDisplay(point.estimated1RM, unit: unit),
                    isPR: isPR
                )
            )
        }
        return out
    }

    private func prColor(_ trend: PRTrend) -> Color {
        switch trend {
        case .climbing:  return Tint.primary
        case .plateaued: return Ink.secondary
        case .slipping:  return Tint.danger
        }
    }

    private func prLabel(_ stat: StrengthOutlookStat) -> String {
        switch stat.trend {
        case .climbing:
            if stat.isFreshPR { return "PR" }
            if let days = stat.daysToPR { return "~\(etaShort(days))" }
            return "up"
        case .plateaued:
            if let w = stat.weeksSinceBest, w > 0 { return "\(w)w flat" }
            return "flat"
        case .slipping:
            return "down"
        }
    }

    private func etaShort(_ days: Int) -> String {
        days <= 21 ? "\(days)d" : "\(Int((Double(days) / 7).rounded()))w"
    }

    private func etaPhrase(_ days: Int) -> String {
        days <= 21 ? "\(days) days" : "\(Int((Double(days) / 7).rounded())) weeks"
    }
}

// MARK: - Chart point

/// A single e1RM sample mapped into display units for the chart, with
/// the record flag so PR sessions can be dotted on the line.
private struct E1RMPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPR: Bool
}
