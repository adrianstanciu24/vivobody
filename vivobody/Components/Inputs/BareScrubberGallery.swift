//
//  BareScrubberGallery.swift
//  vivobody
//
//  Interactive load and reps examples for persistent rail visibility,
//  compact graduation density, and long-value clearance in both appearances.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct BareScrubberGallery: View {
        @State private var weight = 185.5
        @State private var reps = 11.0

        var body: some View {
            VStack(alignment: .leading, spacing: Space.lg) {
                BareScrubber(
                    value: $weight,
                    range: 0 ... 275,
                    step: 0.5,
                    pointsPerStep: 8,
                    fontSize: 104,
                    unit: "kg",
                    unitFontSize: 18,
                    accessibilityLabel: "Weight",
                    fitsWidth: true,
                    showsRail: true,
                    keepsRailVisible: true
                )
                HStack(spacing: Space.sm) {
                    Text("×")
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                    BareScrubber(
                        value: $reps,
                        range: 1 ... 30,
                        pointsPerStep: 16,
                        fontSize: 46,
                        unit: "reps",
                        unitFontSize: 14,
                        accessibilityLabel: "Reps",
                        showsRail: true,
                        keepsRailVisible: true
                    )
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Space.gutter)
            .frame(maxWidth: 374)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Surface.background.ignoresSafeArea())
        }
    }

    #Preview("Scrubber · Dark") {
        BareScrubberGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Scrubber · Light") {
        BareScrubberGallery()
            .preferredColorScheme(.light)
    }
#endif
