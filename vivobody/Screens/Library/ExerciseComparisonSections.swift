//
//  ExerciseComparisonSections.swift
//  vivobody
//
//  Focused Movement and Tracking instruments for Exercise Comparison.
//  Large paired dials carry the leading difference, compact head-to-head
//  lanes handle the remaining authored facts, and longer explanations stay
//  collapsed until requested. Technique links own all setup information.
//

import SwiftUI
import VivoKit

extension ExerciseComparisonScreen {
    // MARK: - Movement panel

    var movementPanel: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            VStack(alignment: .leading, spacing: Space.lg) {
                SectionHeader(title: "Movement")
                    .accessibilityIdentifier("comparison-movement")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Space.md) {
                        movementDial(for: anchor, side: "A", tint: .accent)
                        movementDial(for: other, side: "B", tint: .compare)
                    }

                    VStack(spacing: Space.md) {
                        movementDial(for: anchor, side: "A", tint: .accent)
                        movementDial(for: other, side: "B", tint: .compare)
                    }
                }

                if !movementDetailRows.isEmpty {
                    comparisonFactBoard(rows: movementDetailRows)
                }

                directionDisclosure
            }

            instructionsSection
        }
    }

    private func movementDial(
        for item: ExerciseCatalogItem,
        side: String,
        tint: MuscleMapTint
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text(side)
                    .font(Typography.metricInline)
                    .foregroundStyle(comparisonLabelColor(tint))
                Spacer(minLength: Space.sm)
                Image(systemName: directionSymbol(for: item.direction))
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(comparisonLabelColor(tint))
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            Text(movementDialTitle(for: item))
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.mechanic.displayName)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.tertiary)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .contentCard(bright: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Exercise \(side), \(item.name). \(movementDialTitle(for: item)), \(item.mechanic.displayName)."
        )
    }

    private var movementDetailRows: [ExerciseComparison.FactRow] {
        comparison.movementRows.filter { $0.label != "Pattern" }
    }

    private func movementDialTitle(for item: ExerciseCatalogItem) -> String {
        if let movementLabel = item.movementLabel { return movementLabel }
        if let trainingRole = item.trainingRole { return trainingRole.displayName }
        return item.mechanic == .isolation ? "Isolation" : "Not authored"
    }

    private func directionSymbol(for direction: PushPullDirection?) -> String {
        switch direction {
        case .horizontal: "arrow.left.and.right"
        case .vertical: "arrow.up.and.down"
        case .diagonal: "arrow.up.right"
        case nil: "minus"
        }
    }

    @ViewBuilder
    private var directionDisclosure: some View {
        if let note = comparison.directionNote {
            DisclosureGroup(isExpanded: $showsDirectionExplanation) {
                Text(note)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.md)
            } label: {
                Label("Why this direction?", systemImage: "info.circle")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
            }
            .tint(Ink.tertiary)
            .accessibilityIdentifier("comparison-direction-explanation")
        }
    }

    // MARK: - Tracking panel

    var trackingPanel: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Tracking")
                .accessibilityIdentifier("comparison-tracking")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.md) {
                    recordDial(
                        side: "A",
                        item: anchor,
                        value: anchorRecordValue,
                        tint: .accent
                    )
                    recordDial(
                        side: "B",
                        item: other,
                        value: otherRecordValue,
                        tint: .compare
                    )
                }

                VStack(spacing: Space.md) {
                    recordDial(
                        side: "A",
                        item: anchor,
                        value: anchorRecordValue,
                        tint: .accent
                    )
                    recordDial(
                        side: "B",
                        item: other,
                        value: otherRecordValue,
                        tint: .compare
                    )
                }
            }
            .accessibilityElement(children: .contain)

            if !trackingDetailRows.isEmpty {
                comparisonFactBoard(rows: trackingDetailRows)
            }

            trackingDisclosure
        }
    }

    private func recordDial(
        side: String,
        item: ExerciseCatalogItem,
        value: String,
        tint: MuscleMapTint
    ) -> some View {
        let hasRecord = value != "No records"
        return VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text(side)
                    .font(Typography.metricInline)
                    .foregroundStyle(comparisonLabelColor(tint))
                Spacer(minLength: Space.sm)
                Image(systemName: hasRecord ? "trophy.fill" : "minus.circle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(hasRecord ? comparisonLabelColor(tint) : Ink.tertiary)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            Text(value)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Record format")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.tertiary)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .contentCard(bright: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Records. \(item.name): \(value).")
    }

    private var trackingDetailRows: [ExerciseComparison.FactRow] {
        comparison.trackingRows.filter { $0.label != "Records" }
    }

    private var anchorRecordValue: String {
        recordRow?.anchorValue ?? "No records"
    }

    private var otherRecordValue: String {
        recordRow?.otherValue ?? "No records"
    }

    private var recordRow: ExerciseComparison.FactRow? {
        comparison.trackingRows.first { $0.label == "Records" }
    }

    @ViewBuilder
    private var trackingDisclosure: some View {
        if let note = comparison.progressionNote {
            DisclosureGroup(isExpanded: $showsTrackingExplanation) {
                Text(note)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.md)
            } label: {
                Label("How tracking differs", systemImage: "info.circle")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
            }
            .tint(Ink.tertiary)
            .accessibilityIdentifier("comparison-tracking-explanation")
        }
    }

    // MARK: - Compact comparison board

    private func comparisonFactBoard(
        rows: [ExerciseComparison.FactRow]
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { SectionDivider() }
                comparisonFactLane(row)
            }
        }
        .padding(.horizontal, Space.lg)
        .contentCard()
    }

    @ViewBuilder
    private func comparisonFactLane(_ row: ExerciseComparison.FactRow) -> some View {
        if row.differs {
            VStack(spacing: Space.md) {
                factLaneLabel(row.label)
                HStack(alignment: .top, spacing: Space.lg) {
                    factLaneValue(side: "A", value: row.anchorValue, tint: .accent)
                    factLaneValue(side: "B", value: row.otherValue, tint: .compare)
                }
            }
            .padding(.vertical, Space.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(factAccessibilityLabel(row))
        } else {
            VStack(spacing: Space.sm) {
                factLaneLabel(row.label)
                Text(row.anchorValue)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Both")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(factAccessibilityLabel(row))
        }
    }

    private func factLaneLabel(_ label: String) -> some View {
        Label(label, systemImage: factSymbol(for: label))
            .font(Typography.metricUnit)
            .foregroundStyle(Ink.tertiary)
            .textCase(.uppercase)
    }

    private func factLaneValue(
        side: String,
        value: String,
        tint: MuscleMapTint
    ) -> some View {
        VStack(alignment: side == "A" ? .leading : .trailing, spacing: Space.xs) {
            Text(side)
                .font(Typography.metricUnit)
                .foregroundStyle(comparisonLabelColor(tint))
            Text(value)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .multilineTextAlignment(side == "A" ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(
            maxWidth: .infinity,
            alignment: side == "A" ? .leading : .trailing
        )
    }

    private func factSymbol(for label: String) -> String {
        switch label {
        case "Training": "figure.strengthtraining.traditional"
        case "Mechanic": "link"
        case "Planes": "rotate.3d"
        case "Laterality": "person.2"
        case "Equipment": "dumbbell.fill"
        case "Type": "bolt.fill"
        case "Measured": "ruler"
        case "Load": "scalemass.fill"
        default: "circle.grid.2x2"
        }
    }

    private func factAccessibilityLabel(_ row: ExerciseComparison.FactRow) -> String {
        if row.differs {
            return "\(row.label). \(anchor.name): \(row.anchorValue). "
                + "\(other.name): \(row.otherValue)."
        }
        return "\(row.label). \(anchor.name) and \(other.name): \(row.anchorValue)."
    }

    // MARK: - Technique drill-outs

    @ViewBuilder
    private var instructionsSection: some View {
        let anchorHasSteps = anchor.execution != nil
        let otherHasSteps = other.execution != nil
        if anchorHasSteps || otherHasSteps {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "How to perform")

                VStack(spacing: Space.sm) {
                    if anchorHasSteps {
                        instructionsLink(for: anchor, side: "A", tint: .accent)
                    }
                    if otherHasSteps {
                        instructionsLink(for: other, side: "B", tint: .compare)
                    }
                }
            }
        }
    }

    private func instructionsLink(
        for item: ExerciseCatalogItem,
        side: String,
        tint: MuscleMapTint
    ) -> some View {
        NavigationLink {
            ExerciseInstructionsScreen(item: item)
        } label: {
            HStack(spacing: Space.md) {
                Text(side)
                    .font(Typography.statValueCompact)
                    .foregroundStyle(comparisonLabelColor(tint))
                    .frame(width: 34)

                Text(item.name)
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .contentCard(bright: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("How to perform \(item.name)")
        .accessibilityHint("Opens exercise instructions")
        .accessibilityIdentifier("comparison-how-to-\(side.lowercased())")
    }
}
