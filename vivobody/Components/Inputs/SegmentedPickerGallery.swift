//
//  SegmentedPickerGallery.swift
//  vivobody
//
//  Every SegmentedPicker configuration the app ships: text, two-line
//  custom labels, custom feedback, and accessibility stacking.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct SegmentedPickerGallery: View {
        @State private var step: Double = 5
        @State private var unit: WeightUnit = .lb
        @State private var rir = 2
        @State private var scope = "Exercises"

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    section("STEP") {
                        SegmentedPicker(selection: $step, options: [1.0, 2.5, 5.0]) {
                            WeightUnit.stepLabel($0, unit: "lb")
                        }
                    }
                    section("SCOPE · section heading font") {
                        SegmentedPicker(
                            selection: $scope,
                            options: ["Exercises", "Templates"],
                            font: Typography.sectionHeading
                        ) { $0 }
                    }
                    section("UNITS · two-line labels, stacks at AX sizes") {
                        SegmentedPicker(
                            selection: $unit,
                            options: WeightUnit.allCases,
                            accessibilityLabel: \.displayName,
                            stacksAtAccessibilitySizes: true,
                            minSegmentHeight: Space.rowMin
                        ) { option, _ in
                            VStack(spacing: 2) {
                                Text(option.symbol).font(Typography.metricUnit)
                                Text(option.displayName)
                                    .font(Typography.micro)
                                    .opacity(Opacity.emphasis)
                            }
                        }
                    }
                    section("RIR · custom feedback on reselection") {
                        SegmentedPicker(
                            selection: $rir,
                            options: Array(0 ... 5),
                            feedback: { Haptics.rir($0) },
                            feedbackOnReselection: true
                        ) { RIRSelector.displayLabel($0) }
                    }
                }
                .padding(Space.xxl)
            }
            .screenBackground()
        }

        private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: Space.md) {
                Text(title)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                content()
            }
        }
    }

    #Preview("Segmented Picker · Dark") {
        SegmentedPickerGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Segmented Picker · Light") {
        SegmentedPickerGallery()
            .preferredColorScheme(.light)
    }
#endif
