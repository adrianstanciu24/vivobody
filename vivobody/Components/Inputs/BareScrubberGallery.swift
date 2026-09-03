//
//  BareScrubberGallery.swift
//  vivobody
//
//  Interactive regression gallery for hero fitting, hint, and rail visuals.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct BareScrubberGallery: View {
        @State private var weight = 192.5

        var body: some View {
            VStack(alignment: .leading, spacing: Space.lg) {
                BareScrubber(
                    value: $weight,
                    range: 0 ... 275,
                    step: 2.5,
                    pointsPerStep: 8,
                    fontSize: 104,
                    unit: "kg",
                    unitFontSize: 18,
                    accessibilityLabel: "Weight",
                    showsScrubHint: true,
                    fitsWidth: true,
                    showsRail: true
                )
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            }
            .padding(.horizontal, 20)
            .frame(width: 334)
            .border(Color.red.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
    }

    #Preview("Bare Scrubber") {
        BareScrubberGallery()
            .preferredColorScheme(.dark)
    }
#endif
