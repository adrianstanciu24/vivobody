//
//  TemplateLoadControls.swift
//  vivobody
//
//  Shared template input for remembered versus deliberately fixed loads.
//  Missing initial loads require an explicit entry, including intentional zero.
//

import SwiftUI
import VivoKit

struct TemplateLoadControls: View {
    @Binding var policy: TemplateLoadPolicy
    @Binding var weight: Double
    @Binding var hasStartingLoad: Bool
    let loadMode: ExerciseLoadMode
    let unit: WeightUnit
    let lastWeights: [Double]
    let lastDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Starting load")
                .sectionLabelStyle(Opacity.medium)
            Menu {
                ForEach(TemplateLoadPolicy.allCases, id: \.self) { choice in
                    Button {
                        policy = choice
                    } label: {
                        if choice == policy {
                            Label(choice.title, systemImage: "checkmark")
                        } else {
                            Text(choice.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: Space.sm) {
                    Text(policy.title)
                        .font(Typography.sectionHeading)
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Typography.caption)
                }
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Starting load")
            .accessibilityValue(policy.title)
            .accessibilityIdentifier("templateLoadPolicy")

            if policy == .lastWorkout, !lastWeights.isEmpty {
                Text(TemplateLoadResolution(weights: lastWeights, source: "Last used", date: lastDate)
                    .summary(loadMode: loadMode, unit: unit))
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .accessibilityIdentifier("templateLastUsedLoad")
            } else {
                Text(policy == .fixed ? loadMode.inputLabel : "First workout \(loadMode.inputLabel.lowercased())")
                    .sectionLabelStyle(Opacity.medium)
                if hasStartingLoad {
                    BareScrubber(
                        value: Binding(
                            get: { WeightFormatter.toDisplay(weight, unit: unit) },
                            set: { weight = WeightFormatter.toCanonical($0, unit: unit) }
                        ),
                        range: unit.strengthRange,
                        step: unit.strengthStep,
                        pointsPerStep: 8,
                        fontSize: 56,
                        unit: unit.symbol,
                        unitFontSize: 16,
                        numberColor: Ink.primary,
                        unitColor: Ink.tertiary,
                        accessibilityLabel: loadMode.inputLabel,
                        tickTone: .deep
                    )
                } else {
                    Button {
                        hasStartingLoad = true
                    } label: {
                        Text("Set starting load")
                            .font(Typography.sectionHeading)
                            .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("templateSetStartingLoad")
                }
            }
        }
    }
}

#if DEBUG
    struct TemplateLoadControlsGallery: View {
        @State private var policy: TemplateLoadPolicy = .lastWorkout
        @State private var weight: Double = 135
        @State private var hasStartingLoad = false

        var body: some View {
            TemplateLoadControls(policy: $policy, weight: $weight, hasStartingLoad: $hasStartingLoad,
                                 loadMode: .external, unit: .lb, lastWeights: [155, 155, 150], lastDate: Date())
                .padding()
                .screenBackground()
        }
    }

    #Preview { TemplateLoadControlsGallery() }
#endif
