//
//  MovementCompositionSection.swift
//
//  The compound-vs-isolation split of your working sets over the last
//  four weeks: how much sits in multi-joint compound lifts (bench,
//  squat, deadlift, press) versus single-joint isolation work (curls,
//  extensions, leg curls). A 100% stacked bar (Swift Charts) shows
//  the balance at a glance with inline percentage labels; a
//  structured legend below carries the mechanic names, joint counts,
//  set counts, and percentages. One line reads the emphasis.
//
//  Compound wears the accent as the productive backbone; isolation
//  sits in grayscale luminance — one accent, hierarchy by
//  brightness, like the rest of the app and the IntensityMix section.
//

import SwiftUI
import Charts

struct MovementCompositionSection: View {
    let split: CompositionSplit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Movement", trailing: "last 4 weeks")

            if !split.hasData {
                Text("As you log weighted sets, this splits them into compound (multi-joint) and isolation (single-joint) lifts so you can see whether your training leans toward the big basics or targeted work.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                insight
                compositionChart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var compositionChart: some View {
        VStack(spacing: Space.md) {
            Chart(slices) { slice in
                BarMark(
                    x: .value("Percent", split.share(slice.mechanic) * 100),
                    y: .value("Category", "All")
                )
                .foregroundStyle(by: .value("Mechanic", slice.mechanic.displayName))
                .annotation(position: .overlay) {
                    if split.share(slice.mechanic) > 0.08 {
                        Text("\(Int((split.share(slice.mechanic) * 100).rounded()))%")
                            .font(Typography.metricMicro)
                            .foregroundStyle(labelColor(slice.mechanic))
                            .monospacedDigit()
                    }
                }
            }
            .chartForegroundStyleScale(domain: Mechanic.allCases.map(\.displayName), range: Mechanic.allCases.map { color($0) })
            .chartLegend(.hidden)
            .chartXScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .accessibilityLabel("Movement composition distribution")

            legend

            if split.unclassifiedSets > 0 {
                Text("+\(split.unclassifiedSets) \(split.unclassifiedSets == 1 ? "set" : "sets") unclassified")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(spacing: Space.sm) {
            ForEach(slices) { slice in
                HStack(spacing: Space.sm) {
                    Circle()
                        .fill(color(slice.mechanic))
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(slice.mechanic.displayName)
                        .font(Typography.body)
                        .foregroundStyle(Ink.primary)
                    Text(subLabel(slice.mechanic))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                    Spacer(minLength: Space.sm)
                    Text("\(slice.count) \(slice.count == 1 ? "set" : "sets")")
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                    Text("\(Int((split.share(slice.mechanic) * 100).rounded()))%")
                        .font(Typography.metricUnit)
                        .foregroundStyle(slice.mechanic == split.dominant ? Tint.primary : Ink.tertiary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Insight line

    private var insight: some View {
        Text(line)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var line: AttributedString {
        let compoundShare = split.share(.compound)
        let isolationShare = split.share(.isolation)

        if compoundShare > 0.60 {
            let pct = Int((compoundShare * 100).rounded())
            var lead = AttributedString("Compound-led"); lead.foregroundColor = Ink.primary
            var dash = AttributedString(" — "); dash.foregroundColor = Ink.secondary
            var num = AttributedString("\(pct)% "); num.foregroundColor = Ink.primary
            var rest = AttributedString("of your sets are big multi-joint lifts."); rest.foregroundColor = Ink.secondary
            return lead + dash + num + rest
        }

        if isolationShare > 0.60 {
            let pct = Int((isolationShare * 100).rounded())
            var lead = AttributedString("Isolation-heavy"); lead.foregroundColor = Ink.primary
            var dash = AttributedString(" — "); dash.foregroundColor = Ink.secondary
            var num = AttributedString("\(pct)% "); num.foregroundColor = Ink.primary
            var rest = AttributedString("single-joint work."); rest.foregroundColor = Ink.secondary
            return lead + dash + num + rest
        }

        var a = AttributedString("A balanced "); a.foregroundColor = Ink.primary
        var b = AttributedString("compound/isolation mix."); b.foregroundColor = Ink.secondary
        return a + b
    }

    // MARK: - Derived

    private var slices: [CompositionSlice] {
        Mechanic.allCases.compactMap { mechanic in
            let count = split.count(mechanic)
            guard count > 0 else { return nil }
            return CompositionSlice(mechanic: mechanic, count: count)
        }
    }

    private func color(_ m: Mechanic) -> Color {
        switch m {
        case .compound:  return Tint.primary
        case .isolation: return Ink.secondary
        }
    }

    /// Label color per mechanic for readability inside the bar — dark
    /// text on the bright accent and on the light gray isolation
    /// segment.
    private func labelColor(_ m: Mechanic) -> Color {
        switch m {
        case .compound:  return Tint.onAccent.opacity(0.85)
        case .isolation: return .black.opacity(0.7)
        }
    }

    private func subLabel(_ m: Mechanic) -> String {
        switch m {
        case .compound:  return "multi-joint"
        case .isolation: return "single-joint"
        }
    }
}

// MARK: - Chart data

private struct CompositionSlice: Identifiable {
    let id = UUID()
    let mechanic: Mechanic
    let count: Int
}
