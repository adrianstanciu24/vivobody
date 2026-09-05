//
//  TrainingDimensionsGallery.swift
//  vivobody
//
//  DEBUG gallery for the shared plane glyph and rep-series instrument, including
//  a held-back set. The live semantic fixtures verify the integrated screens.
//

import SwiftUI
import VivoKit

#if DEBUG
    private struct TrainingDimensionsGallery: View {
        @State private var heldBack = false

        var body: some View {
            ScrollView {
                VStack(spacing: Space.xxl) {
                    MovementPlanesGlyph(
                        activePlanes: [.sagittal, .frontal, .transverse],
                        shares: [.sagittal: 0.91, .frontal: 0.06, .transverse: 0.03]
                    )
                    .frame(height: 180)
                    Toggle("Higher RIR on last set", isOn: $heldBack)
                    ExerciseStaminaInstrument(report: ExerciseStamina(series: [run]))
                }
                .padding(Space.gutter)
            }
            .screenBackground()
        }

        private var run: StaminaSeries {
            StaminaSeries(
                id: "gallery", date: Date(), historyKey: "bench", name: "Bench Press", pattern: .push,
                loadProfile: .init(mode: .external, bodyweightFraction: 0), bodyweight: 0,
                weight: 135, reps: [10, 9, 8], rir: [2, 2, heldBack ? 4 : 1],
                heldBackIndices: heldBack ? [2] : []
            )
        }
    }

    #Preview("Training dimensions") {
        TrainingDimensionsGallery()
    }
#endif
