//
//  MovementCoverageSection.swift
//  vivobody
//
//  Anatomical-plane arcs and an on-demand roster of unrecorded planes/actions.
//  The familiar Movement glyph carries the distribution; prose stays in help.
//

import SwiftUI
import VivoKit

struct MovementCoverageSection: View {
    let report: MovementCoverage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink {
            MovementCoverageDetail(report: report)
        } label: {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Movement coverage").font(Typography.title)
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.right").font(Typography.caption)
                }
                .foregroundStyle(Ink.primary)
                Text("All time").panelLegend()
                if report.hasData {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: Space.xl) {
                            glyph.frame(height: 150)
                            planeLabels
                        }
                    } else {
                        HStack(spacing: Space.xl) {
                            glyph.frame(width: 130, height: 150)
                            planeLabels
                        }
                    }
                } else {
                    Text("No classified hard sets yet")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                }
                if report.unclassifiedSets > 0 {
                    Text("\(InsightsFormat.setsLabel(report.unclassifiedSets)) hard sets unclassified")
                        .font(Typography.caption).foregroundStyle(Ink.secondary)
                }
            }
            .padding(Space.xl)
            .contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insightsMovementCoverageLink")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens planes and joint actions not recorded in your training history")
    }

    private var glyph: some View {
        MovementPlanesGlyph(
            activePlanes: Set(MovementPlane.allCases.filter { report.share($0) > 0 }),
            shares: Dictionary(uniqueKeysWithValues: MovementPlane.allCases.map { ($0, report.share($0)) })
        )
        .padding(Space.xs)
    }

    private var planeLabels: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            ForEach(MovementPlane.allCases, id: \.self) { plane in
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.md))
                layout {
                    Text(plane.displayName).font(Typography.body)
                        .foregroundStyle(Ink.secondary).fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Text("\(report.percentage(plane))%")
                        .font(Typography.statValueCompact).monospacedDigit()
                        .foregroundStyle(report.share(plane) > 0 ? Tint.primaryText : Ink.tertiary)
                        .fixedSize()
                }
            }
        }
    }

    private var accessibilityLabel: String {
        let shares = MovementPlane.allCases.map {
            "\($0.displayName), \(report.percentage($0)) percent"
        }.joined(separator: ". ")
        let coverage = "\(InsightsFormat.setsLabel(report.unclassifiedSets)) hard sets unclassified."
        return "Movement coverage. All time. \(report.hasData ? shares : "No classified hard sets"). \(coverage)"
    }
}

private struct MovementCoverageDetail: View {
    let report: MovementCoverage

    var body: some View {
        InsightsDrilloutScreen(title: "Movement coverage") {
            VStack(alignment: .leading, spacing: Space.xxl) {
                Text("Not recorded · all time").font(Typography.title)
                    .accessibilityIdentifier("movementCoverageGaps")
                    .accessibilityAddTraits(.isHeader)
                if report.totalSets == 0 {
                    Text("No hard sets recorded. Coverage builds from completed strength work.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                }
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("Planes").font(Typography.sectionHeading).accessibilityAddTraits(.isHeader)
                    if report.missingPlanes.isEmpty {
                        Label("All three planes recorded", systemImage: "checkmark.circle")
                            .font(Typography.body).foregroundStyle(Ink.secondary)
                    }
                    ForEach(report.missingPlanes, id: \.self) { plane in
                        DisclosureGroup {
                            familyNames(report.families(for: plane))
                        } label: {
                            Text(plane.displayName).font(Typography.headline)
                                .frame(minHeight: 44)
                        }
                    }
                }
                .padding(Space.xl).contentCard()

                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Joint actions").font(Typography.sectionHeading).accessibilityAddTraits(.isHeader)
                    if report.unknownActionSets > 0 {
                        Text("\(InsightsFormat.setsLabel(report.unknownActionSets)) hard sets have no family actions recorded.")
                            .font(Typography.caption).foregroundStyle(Ink.secondary)
                    }
                    if report.missingActions.isEmpty {
                        Text("Every catalog action recorded").font(Typography.body)
                    }
                    ForEach(report.missingActions) { gap in
                        DisclosureGroup {
                            familyNames(gap.families)
                        } label: {
                            Text(gap.action.displayName).font(Typography.body)
                                .foregroundStyle(Ink.primary).frame(minHeight: 44)
                        }
                    }
                }
                .padding(Space.xl).contentCard()

                DisclosureGroup("How coverage is counted") {
                    Text("Hard-set credit is shared equally across an exercise’s planes. Joint actions come from its catalog family; producing, resisting, and yielding stay separate. Unclassified work cannot establish an absence. These are recorded gaps, not training recommendations.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                        .padding(.top, Space.sm)
                }
                .font(Typography.body).frame(minHeight: 44)
            }
        }
    }

    private func familyNames(_ families: [CatalogMovementFamily]) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            ForEach(families) { family in
                Text(family.name).font(Typography.body).foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, Space.sm)
    }
}
