//
//  ExerciseComparisonMusclePanel.swift
//  vivobody
//
//  Muscle-first comparison instrument. Mirrored beams put each authored
//  muscle role on one common visual scale, while a compact scope switch and
//  per-side anatomy view preserve the distinction between training volume
//  and anatomical involvement without explanatory walls of text.
//

import SwiftUI
import VivoKit

extension ExerciseComparisonScreen {
    // MARK: - Muscle panel

    @ViewBuilder
    var musclesPanel: some View {
        if comparison.muscleDeltas.isEmpty {
            emptyMusclePanel
        } else {
            VStack(alignment: .leading, spacing: Space.section) {
                volumeEligibilityInstrument
                muscleGaugeInstrument
                GroupSeparator(verticalPadding: 0)
                anatomyInstrument
            }
        }
    }

    private var volumeEligibilityInstrument: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "Training volume",
                trailing: dynamicTypeSize.isAccessibilitySize
                    ? nil
                    : volumeAvailabilityShortLabel
            )

            HStack(spacing: 0) {
                volumeEligibilityCell(
                    side: "A",
                    eligible: anchorIsVolumeEligible,
                    tint: .accent
                )

                Rectangle()
                    .fill(Surface.edge)
                    .frame(width: 1, height: 46)
                    .accessibilityHidden(true)

                volumeEligibilityCell(
                    side: "B",
                    eligible: otherIsVolumeEligible,
                    tint: .compare
                )
            }
            .padding(.vertical, Space.md)
            .contentCard(bright: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training volume, \(volumeAvailabilityAccessibilityLabel)")
        .accessibilityIdentifier("comparison-stimulus")
    }

    private func volumeEligibilityCell(
        side: String,
        eligible: Bool,
        tint: MuscleMapTint
    ) -> some View {
        HStack(spacing: Space.md) {
            Text(side)
                .font(Typography.statValueCompact)
                .foregroundStyle(comparisonLabelColor(tint))
                .monospacedDigit()

            VStack(alignment: .leading, spacing: Space.xs) {
                Image(systemName: eligible ? "checkmark" : "minus")
                    .font(Typography.title)
                    .foregroundStyle(eligible ? comparisonLabelColor(tint) : Ink.tertiary)
                    .accessibilityHidden(true)

                Text(eligible ? "Eligible" : "No credit")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .center)
    }

    private var muscleGaugeInstrument: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Muscle balance",
                trailing: dynamicTypeSize.isAccessibilitySize
                    ? nil
                    : (muscleScope == .trainingVolume ? "volume credit" : "all roles")
            )
            .accessibilityIdentifier("comparison-muscles")

            scopeSelector

            if displayedMuscleDeltas.isEmpty {
                noVolumeGaugeState
            } else {
                VStack(spacing: Space.xl) {
                    ForEach(displayedMuscleDeltas, id: \.muscle) { delta in
                        MuscleComparisonGauge(
                            delta: delta,
                            scope: muscleScope,
                            anchorName: anchor.name,
                            otherName: other.name,
                            anchorColor: comparisonLabelColor(.accent),
                            otherColor: comparisonLabelColor(.compare)
                        )
                    }
                }
                .padding(.vertical, Space.sm)
            }
        }
    }

    private var scopeSelector: some View {
        choiceBar {
            choiceButton(
                label: "Volume",
                selected: muscleScope == .trainingVolume,
                tint: comparisonControlFillColor(.accent)
            ) {
                muscleScope = .trainingVolume
            }
            .accessibilityLabel("Training volume")
            .accessibilityIdentifier("comparison-muscle-scope-volume")

            choiceButton(
                label: "All roles",
                selected: muscleScope == .allInvolvement,
                tint: comparisonControlFillColor(.accent)
            ) {
                muscleScope = .allInvolvement
            }
            .accessibilityLabel("All involvement")
            .accessibilityIdentifier("comparison-muscle-scope-all")
        }
    }

    private var noVolumeGaugeState: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("No training-volume signal")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)

            Button("Show anatomical roles") {
                Haptics.selection()
                muscleScope = .allInvolvement
            }
            .font(Typography.sectionHeading)
            .foregroundStyle(Tint.primary)
            .frame(minHeight: Space.tapMin)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private var displayedMuscleDeltas: [ExerciseComparison.MuscleDelta] {
        switch muscleScope {
        case .trainingVolume:
            comparison.muscleDeltas.filter {
                $0.anchorVolumeCredit > 0 || $0.otherVolumeCredit > 0
            }
        case .allInvolvement:
            comparison.muscleDeltas
        }
    }

    // MARK: - Anatomy instrument

    private var anatomyInstrument: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "Anatomy",
                trailing: dynamicTypeSize.isAccessibilitySize
                    ? nil
                    : "\(sideLabel) · \(selectedItem.name)"
            )
            .accessibilityIdentifier("comparison-anatomy")

            choiceBar {
                choiceButton(
                    label: "A",
                    selected: anatomySide == .anchor,
                    tint: comparisonControlFillColor(.accent)
                ) {
                    anatomySide = .anchor
                }
                .accessibilityLabel("Exercise A, \(anchor.name)")
                .accessibilityIdentifier("comparison-anatomy-side-a")

                choiceButton(
                    label: "B",
                    selected: anatomySide == .other,
                    tint: comparisonControlFillColor(.compare)
                ) {
                    anatomySide = .other
                }
                .accessibilityLabel("Exercise B, \(other.name)")
                .accessibilityIdentifier("comparison-anatomy-side-b")
            }

            choiceBar {
                choiceButton(
                    label: "Volume",
                    selected: anatomyScope == .trainingVolume,
                    tint: comparisonControlFillColor(.accent)
                ) {
                    anatomyScope = .trainingVolume
                }
                .accessibilityLabel("Training volume")
                .accessibilityIdentifier("comparison-anatomy-scope-volume")

                choiceButton(
                    label: "All roles",
                    selected: anatomyScope == .allInvolvement,
                    tint: comparisonControlFillColor(.accent)
                ) {
                    anatomyScope = .allInvolvement
                }
                .accessibilityLabel("All involvement")
                .accessibilityIdentifier("comparison-anatomy-scope-all")
            }

            VStack(alignment: .leading, spacing: Space.md) {
                anatomyFigure
                anatomyRoleLegend
                unvisualizedNote
            }
            .padding(Space.md)
            .contentCard()
        }
    }

    private func choiceBar(
        @ViewBuilder content: () -> some View
    ) -> some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                content()
            }
            .padding(4)
            .coloredGlassControl(cornerRadius: Radius.pill)
        }
    }

    private func choiceButton(
        label: String,
        selected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !selected else { return }
            Haptics.selection()
            action()
        } label: {
            Text(label)
                .font(Typography.sectionHeading)
                .foregroundStyle(selected ? comparisonControlForegroundColor : Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: Space.tapMin)
                .background {
                    if selected {
                        Color.clear
                            .coloredGlassControl(cornerRadius: Radius.pill, fill: tint)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private var anatomyFigure: some View {
        let channels = comparison.anatomyChannels(for: anatomySide, scope: anatomyScope)
        if channels.isEmpty {
            VStack(spacing: Space.sm) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
                Text(emptyAnatomyMessage)
                    .font(Typography.title)
                    .foregroundStyle(Ink.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .accessibilityLabel(emptyAnatomyMessage)
        } else {
            StagedBodyModel(renderHeight: 260, channels: channels, warmth: 0.55)
                .frame(height: 260)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(anatomyAccessibilityLabel)
        }
    }

    private var anatomyRoleLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.lg) {
                anatomyLegendItem("Primary", intensity: 1)
                anatomyLegendItem("Secondary", intensity: 0.5)
                if anatomyScope == .allInvolvement {
                    anatomyLegendItem("Stabilizer", intensity: 0.2)
                }
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                anatomyLegendItem("Primary", intensity: 1)
                anatomyLegendItem("Secondary", intensity: 0.5)
                if anatomyScope == .allInvolvement {
                    anatomyLegendItem("Stabilizer", intensity: 0.2)
                }
            }
        }
    }

    private func anatomyLegendItem(_ role: String, intensity: Double) -> some View {
        HStack(spacing: Space.sm) {
            Capsule()
                .fill(anatomyTintColor(selectedTint, intensity: intensity))
                .frame(width: 26, height: 7)
                .accessibilityHidden(true)
            Text(role)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
        }
    }

    @ViewBuilder
    private var unvisualizedNote: some View {
        let muscles = comparison.unvisualizedMuscles(for: anatomySide, scope: anatomyScope)
        if !muscles.isEmpty {
            Text("3D view unavailable for " + muscles.map(\.displayName).joined(separator: " · "))
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedItem: ExerciseCatalogItem {
        anatomySide == .anchor ? anchor : other
    }

    private var selectedTint: MuscleMapTint {
        anatomySide == .anchor ? .accent : .compare
    }

    private var sideLabel: String {
        anatomySide == .anchor ? "A" : "B"
    }

    private var emptyAnatomyMessage: String {
        switch anatomyScope {
        case .trainingVolume: "No visual training-volume signal"
        case .allInvolvement: "No visualized muscle roles"
        }
    }

    private var anatomyAccessibilityLabel: String {
        let scope = anatomyScope == .trainingVolume
            ? "Training-volume"
            : "All-involvement"
        return "\(scope) muscle map for Exercise \(sideLabel), \(selectedItem.name)."
    }

    private var emptyMusclePanel: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "figure.stand")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Ink.tertiary)
                .accessibilityHidden(true)
            Text("No authored muscle roles")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityIdentifier("comparison-muscles")
    }

    // MARK: - Volume status

    private var anchorIsVolumeEligible: Bool {
        comparison.trainingVolumeAvailability == .both
            || comparison.trainingVolumeAvailability == .anchorOnly
    }

    private var otherIsVolumeEligible: Bool {
        comparison.trainingVolumeAvailability == .both
            || comparison.trainingVolumeAvailability == .otherOnly
    }

    private var volumeAvailabilityShortLabel: String {
        switch comparison.trainingVolumeAvailability {
        case .both: "both eligible"
        case .anchorOnly: "A only"
        case .otherOnly: "B only"
        case .neither: "neither eligible"
        }
    }

    private var volumeAvailabilityAccessibilityLabel: String {
        switch comparison.trainingVolumeAvailability {
        case .both:
            "Both \(anchor.name) and \(other.name) can earn hard-set volume"
        case .anchorOnly:
            "\(anchor.name) can earn hard-set volume; \(other.name) cannot"
        case .otherOnly:
            "\(other.name) can earn hard-set volume; \(anchor.name) cannot"
        case .neither:
            "Neither \(anchor.name) nor \(other.name) can earn hard-set volume"
        }
    }
}

// MARK: - Mirrored muscle gauge

private struct MuscleComparisonGauge: View {
    let delta: ExerciseComparison.MuscleDelta
    let scope: ExerciseComparison.AnatomyScope
    let anchorName: String
    let otherName: String
    let anchorColor: Color
    let otherColor: Color

    private let barHeight: CGFloat = 20
    private let centerGap: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(delta.muscle.displayName)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.md) {
                Text(roleLabel(role: delta.anchorRole, strength: anchorStrength))
                    .foregroundStyle(anchorColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(roleLabel(role: delta.otherRole, strength: otherStrength))
                    .foregroundStyle(otherColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(Typography.metricUnit)
            .textCase(.uppercase)

            mirroredBeam
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var mirroredBeam: some View {
        GeometryReader { geometry in
            let halfWidth = (geometry.size.width - centerGap) / 2
            ZStack {
                HStack(spacing: centerGap) {
                    beamHalf(
                        width: halfWidth * anchorStrength,
                        color: anchorColor,
                        alignment: .trailing
                    )
                    beamHalf(
                        width: halfWidth * otherStrength,
                        color: otherColor,
                        alignment: .leading
                    )
                }

                Capsule()
                    .fill(Ink.primary.opacity(0.72))
                    .frame(width: 2, height: barHeight + 8)
                    .shadow(color: Ink.primary.opacity(0.18), radius: 4)
            }
        }
        .frame(height: barHeight)
    }

    private func beamHalf(
        width: CGFloat,
        color: Color,
        alignment: Alignment
    ) -> some View {
        ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Surface.cardTintBright)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: width)
        }
    }

    private var anchorStrength: Double {
        strength(role: delta.anchorRole, volumeCredit: delta.anchorVolumeCredit)
    }

    private var otherStrength: Double {
        strength(role: delta.otherRole, volumeCredit: delta.otherVolumeCredit)
    }

    private func strength(role: MuscleRole?, volumeCredit: Double) -> Double {
        switch scope {
        case .trainingVolume: volumeCredit
        case .allInvolvement: role?.anatomyIntensity ?? 0
        }
    }

    private func roleLabel(role: MuscleRole?, strength: Double) -> String {
        switch scope {
        case .trainingVolume:
            if strength >= 0.999 { return "Full" }
            if strength > 0 { return "Partial" }
            return "—"
        case .allInvolvement:
            return role?.displayName ?? "—"
        }
    }

    private func roleDescription(role: MuscleRole?, strength: Double) -> String {
        switch scope {
        case .trainingVolume:
            if strength >= 0.999 { return "full training-volume credit" }
            if strength > 0 { return "partial training-volume credit" }
            return "no training-volume credit"
        case .allInvolvement:
            return role.map { "\($0.displayName) role" } ?? "not involved"
        }
    }

    private var accessibilityText: String {
        "\(delta.muscle.displayName). \(anchorName): "
            + roleDescription(role: delta.anchorRole, strength: anchorStrength)
            + ". \(otherName): "
            + roleDescription(role: delta.otherRole, strength: otherStrength)
            + "."
    }
}
