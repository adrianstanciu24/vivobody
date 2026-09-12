//
//  MovementCoverageSection.swift
//  vivobody
//
//  Standalone plane illustrations and comparable all-time hard-set share bars.
//

import SwiftUI
import VivoKit

struct MovementCoverageSection: View {
    let report: MovementCoverage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Movement coverage")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Text("All time · hard-set share").panelLegend()
            if report.hasData {
                ForEach(MovementPlane.allCases, id: \.self) { plane in
                    planeRow(plane)
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
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("insightsMovementCoverageCard")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let shares = MovementPlane.allCases.map {
            "\($0.displayName), \(direction($0)), \(report.percentage($0)) percent"
        }.joined(separator: ". ")
        let summary = report.hasData ? "Classified hard-set share. \(shares)" : "No classified hard sets yet"
        return "Movement coverage. All time. \(summary). \(InsightsFormat.setsLabel(report.unclassifiedSets)) hard sets unclassified."
    }

    private func planeRow(_ plane: MovementPlane) -> some View {
        HStack(spacing: Space.md) {
            MovementPlaneIllustration(plane: plane)
                .frame(width: MovementPlaneIllustration.designSize.width, height: MovementPlaneIllustration.designSize.height)
            VStack(alignment: .leading, spacing: Space.sm) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.sm))
                layout {
                    Text(plane.displayName)
                        .font(Typography.body).foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Text("\(report.percentage(plane))%")
                        .font(Typography.statValueCompact).monospacedDigit()
                        .foregroundStyle(report.share(plane) > 0 ? Tint.primary : Ink.tertiary)
                        .fixedSize()
                }
                Text(direction(plane))
                    .font(Typography.caption).foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { proxy in
                    Capsule().fill(Ink.quaternary)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Tint.primary)
                                .frame(width: proxy.size.width * report.share(plane))
                        }
                }
                .frame(height: InstrumentBarHeight.micro)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plane.displayName). \(direction(plane)). \(report.percentage(plane)) percent of classified hard-set credit, all time.")
    }

    private func direction(_ plane: MovementPlane) -> String {
        switch plane {
        case .sagittal: "Forward and backward"
        case .frontal: "Sideways"
        case .transverse: "Rotation and across the body"
        }
    }
}
