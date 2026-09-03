//
//  WorkoutLoadComparisonChartGallery.swift
//  vivobody
//
//  DEBUG gallery for inspecting the shared workout-load comparison instrument.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct WorkoutLoadComparisonChartGallery: View {
        private let comparison = WorkoutLoadComparison.make(
            current: WorkoutLoadTrace(setLoads: [420, 380, 520, 410, 610]),
            baseline: WorkoutLoadBaseline.make(traces: [
                WorkoutLoadTrace(setLoads: [350, 390, 430, 460, 500]),
                WorkoutLoadTrace(setLoads: [400, 440, 470, 520]),
                WorkoutLoadTrace(setLoads: [320, 360, 410, 450, 470, 490]),
            ])
        )!

        var body: some View {
            ScrollView {
                WorkoutLoadComparisonChart(comparison: comparison, unit: .lb)
                    .padding(Space.xl)
                    .contentCard()
                    .padding(Space.gutter)
            }
            .screenBackground()
        }
    }

    #Preview("Workout load comparison") {
        WorkoutLoadComparisonChartGallery()
            .preferredColorScheme(.dark)
    }
#endif
