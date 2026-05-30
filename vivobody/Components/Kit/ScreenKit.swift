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

import SwiftUI

// MARK: - Section header

/// The label that sits above a section. Sentence case, tertiary ink,
/// optional dim trailing note ("3 sessions", "vs last week").
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .sectionLabelStyle(0.55)
            if let trailing {
                Spacer(minLength: Space.sm)
                Text(trailing)
                    .sectionLabelStyle(0.40)
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
            .fill(Surface.edge)
            .frame(height: 1)
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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                cell(stat)
                if index < stats.count - 1 {
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(width: 0.5, height: 34)
                }
            }
        }
    }

    private func cell(_ stat: Stat) -> some View {
        VStack(spacing: Space.xs + 2) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(stat.value)
                    .font(valueFont)
                    .foregroundStyle(stat.accent ? Tint.primary : Ink.primary)
                    .monospacedDigit()
                if let unit = stat.unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(stat.label)
                .sectionLabelStyle(0.45)
        }
        .frame(maxWidth: .infinity)
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
                .sectionLabelStyle(0.45)
        }
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Space.sm)

            trailing()
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.md)
        .glassCard()
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
                .glassCard()
            }

            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "This week", trailing: "vs last week")
                MetricView(label: "Total volume", value: "51.5k", unit: "lb")
                    .padding(Space.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
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
