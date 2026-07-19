//
//  ScreenKit.swift
//  vivobody
//
//  The shared layout vocabulary every tab composes from. Screens
//  stopped hand-rolling their own section headers, stat rows, and
//  list rows — that divergence is exactly what made the app look
//  like four different apps. From here on a screen is an arrangement
//  of these primitives, so spacing, type, and surfaces are identical
//  everywhere by construction.
//
//  Primitives:
//    • SectionHeader — sentence-case label + optional trailing note.
//    • StatStrip / Stat — the n-up "big number · label" row with
//      hairline dividers (Today's last-workout, History hero, Me).
//    • MetricView — a single left-aligned label + hero number + unit.
//    • KitRow — the canonical list row (title, subtitle, trailing
//      value) on the one card surface, at the min glanceable height.
//
//  All colour comes from `Ink` / `Tint`; all spacing from `Space`;
//  all type from `Typography`. No literals.
//

import VivoKit
import SwiftUI

// MARK: - Section header

/// The label that sits above a section. A bold sentence-case heading
/// that reads as a clear "new chapter" cue as you scroll, paired with
/// an optional dim trailing note ("3 sessions", "vs last week"). The
/// size contrast between the two is what announces the transition.
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingIsInProgress: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .textCase(nil)
                .tracking(0)
                .accessibilityAddTraits(.isHeader)
            if let trailing {
                Spacer(minLength: Space.sm)
                HStack(spacing: Space.sm) {
                    if trailingIsInProgress {
                        InProgressDot()
                    }
                    Text(trailing)
                        .panelLegend()
                }
            }
        }
        .padding(.top, Space.sm)
    }
}

/// A quiet live-state cue used beside a section header's trailing
/// status. It breathes while work is still forming and freezes to a
/// steady orange dot when Reduce Motion is enabled.
private struct InProgressDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(Tint.inProgress)
            .frame(width: 8, height: 8)
            .opacity(reduceMotion || isBright ? 1.0 : 0.62)
            .scaleEffect(reduceMotion || isBright ? 1.0 : 0.82)
            .shadow(
                color: Tint.inProgress.opacity(reduceMotion || isBright ? 0.45 : 0.12),
                radius: reduceMotion || isBright ? 4 : 2
            )
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isBright = true
                }
            }
    }
}

// MARK: - Section divider

/// A full-width hairline that separates instrument sections on black.
/// The card-free counterpart to a boxed group: structure comes from
/// the line and the whitespace around it, not a filled surface.
struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Surface.edge, location: 0.3),
                        .init(color: Surface.edgeBright, location: 0.5),
                        .init(color: Surface.edge, location: 0.7),
                        .init(color: Color.clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Group separator between major sections on a long scroll screen:
/// a full-width hairline with generous air on both sides so each
/// group reads as its own block. Distinct from a bare `SectionDivider`
/// used as an inline row separator (which carries no vertical padding).
struct GroupSeparator: View {
    var body: some View {
        SectionDivider()
            .padding(.vertical, Space.xxl)
    }
}

// MARK: - Stat strip

/// One cell within a `StatStrip`: a big number, an optional unit
/// suffix, and a label beneath. The number uses tabular figures so
/// it never jitters.
struct Stat: Identifiable {
    let id = UUID()
    let value: String
    var unit: String? = nil
    let label: String
    /// When true the value is tinted Volt — reserved for the one
    /// figure on the strip that's worth celebrating (e.g. streak).
    var accent: Bool = false
}

/// A row of stats separated by hairline dividers. The single source
/// of truth for the "time · volume · sets" pattern that previously
/// existed in three slightly-different copies.
struct StatStrip: View {
    let stats: [Stat]
    var valueFont: Font = Typography.statValue
    /// When true the outer cells hug the strip's edges (first leading,
    /// last trailing) while the middle stays centred. Lets the strip
    /// line up under a gutter-to-gutter section header — the title
    /// sits over the first value, the trailing note over the last.
    /// Default stays fully centred so existing strips are unchanged.
    var edgeAligned: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                cell(stat, alignment: alignment(for: index))
                if index < stats.count - 1 {
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(width: 0.5)
                        .frame(minHeight: 34)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func alignment(for index: Int) -> HorizontalAlignment {
        guard edgeAligned else { return .center }
        if index == 0 { return .leading }
        if index == stats.count - 1 { return .trailing }
        return .center
    }

    private func cell(_ stat: Stat, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Space.xs + 2) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(stat.value)
                    .font(valueFont)
                    .foregroundStyle(stat.accent ? Tint.primary : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit = stat.unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(stat.label)
                .panelLegend()
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.value)\(stat.unit.map { " \($0)" } ?? "") \(stat.label)")
    }
}

// MARK: - Share bar

/// A thin horizontal proportion bar. Used for the session
/// "waterfall": each exercise's share of the workout's volume (or
/// hold-time). Renders as a discrete SegmentLadder — devices count
/// in steps, so a column of these reads as a bank of gauges, and the
/// discreteness matches the app's detent-based sound world.
struct ShareBar: View {
    /// 0…1 portion of the track to fill.
    let fraction: Double
    var tint: Color = Ink.secondary

    var body: some View {
        SegmentLadder(fraction: fraction, segments: 24, tint: tint)
    }
}

/// One row of the session "waterfall": a proportion bar plus a
/// trailing percentage. `isDuration` dims the bar to mark hold-time,
/// which is normalised against the session's holds rather than its
/// weight-volume (a separate pool).
struct WaterfallRow: View {
    let share: Double
    var isDuration: Bool = false

    var body: some View {
        HStack(spacing: Space.sm) {
            ShareBar(fraction: share, tint: isDuration ? Ink.tertiary : Ink.secondary)
            Text("\(Int((share * 100).rounded()))%")
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.quaternary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .frame(width: 38, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((share * 100).rounded())) percent of session volume")
    }
}

// MARK: - Adherence badge

/// The planned-vs-actual delta chip for an exercise row — "+5 lb",
/// "-1 rep", "+0:05". A set that beat the plan wears the completion
/// accent; a shortfall stays dim. Renders nothing when the achieved
/// top set matched the plan (so on-plan rows stay uncluttered) or
/// when there's no plan to compare against.
struct AdherenceBadge: View {
    let adherence: ExerciseAdherence
    let unit: WeightUnit

    var body: some View {
        if let text = label {
            Text(text)
                .font(Typography.metricMicro)
                .foregroundStyle(adherence.beatPlan ? Tint.complete : Ink.tertiary)
                .monospacedDigit()
        }
    }

    private var label: String? {
        if adherence.weightDelta != 0 {
            return WeightFormatter.deltaString(adherence.weightDelta, unit: unit)
        }
        if adherence.isDuration {
            guard adherence.durationDelta != 0 else { return nil }
            return DurationFormatter.deltaString(adherence.durationDelta)
        }
        if adherence.repsDelta != 0 {
            let n = abs(adherence.repsDelta)
            let sign = adherence.repsDelta > 0 ? "+" : "-"
            return "\(sign)\(n) \(n == 1 ? "rep" : "reps")"
        }
        return nil
    }
}

// MARK: - Metric block

/// A single left-aligned metric: small label, big number, unit. Used
/// as a card's hero figure (History "this week" volume, etc.).
struct MetricView: View {
    let label: String
    let value: String
    var unit: String? = nil
    var valueFont: Font = Typography.metricHero
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(valueFont)
                    .foregroundStyle(accent ? Tint.primary : Ink.primary)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(label)
                .panelLegend()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value)\(unit.map { " \($0)" } ?? "") \(label)")
    }
}

// MARK: - List row

/// The canonical list row. Title + optional subtitle on the left, an
/// optional trailing value on the right, on the one card surface at
/// the minimum glanceable height. `leading` lets callers slot an
/// icon or index; `trailing` an arbitrary accessory.
struct KitRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var leading: Image? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Space.md) {
            if let leading {
                leading
                    .font(Typography.headline)
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: Space.sm)

            trailing()
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.md)
        .contentCard()
        .accessibilityElement(children: .contain)
    }
}

extension KitRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, leading: Image? = nil) {
        self.init(title: title, subtitle: subtitle, leading: leading) { EmptyView() }
    }
}

// MARK: - Screen background

extension View {
    /// The one background every tab uses: pure black, edge to edge.
    func screenBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Surface.background.ignoresSafeArea())
    }
}

#Preview("Screen kit") {
    ScrollView {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Last workout", trailing: "9:38 PM")
                StatStrip(stats: [
                    Stat(value: "44", unit: "min", label: "Time"),
                    Stat(value: "12.7k", unit: "lb", label: "Volume"),
                    Stat(value: "12", label: "Sets"),
                ])
                .padding(Space.xl)
                .contentCard()
            }

            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "This week", trailing: "vs last week")
                MetricView(label: "Total volume", value: "51.5k", unit: "lb")
                    .padding(Space.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentCard()
            }

            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Exercises", trailing: "12 tracked")
                KitRow(title: "Bench Press", subtitle: "Barbell · Push") {
                    Text("135×8")
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                }
                KitRow(title: "Back Squat", subtitle: "Barbell · Legs")
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.xl)
    }
    .screenBackground()
    .preferredColorScheme(.dark)
}
