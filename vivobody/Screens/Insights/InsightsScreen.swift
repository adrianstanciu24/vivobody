//
//  InsightsScreen.swift
//  vivobody
//
//  The Insights tab, structured as a sequence of movements rather
//  than a wall of lookalike bars:
//
//    1. Signature — the generative hero: one mark for the whole shape
//       of your training (no body here; the 3D figure is Today's).
//    2. Strength — an estimated-1RM line chart per lift, a record line
//       to chase (Swift Charts, not bars).
//    3. Composition — which lifts carry your volume (exercise dominance).
//    4. Intensity — rep-range distribution of working sets (snapshot).
//    5. Rep trend — average reps/set drifting heavier or lighter over
//       time (the temporal companion to the intensity snapshot).
//    6. Movement — compound vs isolation split of working sets.
//    7. Rhythm — the consistency heatmap plus a weekly-volume curve.
//    8. Load — acute:chronic workload ratio (recovery debt).
//    9. Symmetry — the antagonist-balance coda.
//
//  Each section owns its own copy and colours; this screen fetches the
//  data, runs the value-type models, and lays the movements out
//  gutter-to-gutter with a hairline between each. Visual language
//  follows the rest of the app: black, type-forward, the single orange
//  accent for "on target," danger-red only where something's slipping.
//

import SwiftUI
import SwiftData

struct InsightsScreen: View {
    @Bindable var appState: AppState

    /// All archived sessions. Drives every figure on the screen; the
    /// models are recomputed each render (the dataset is small and
    /// memoizing would risk staleness after a History edit).
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil }
    )
    private var completedSessions: [WorkoutSession]

    var body: some View {
        Group {
            if completedSessions.isEmpty {
                emptyState
            } else {
                loadedContent
            }
        }
        .forgeBackground()
    }

    private var loadedContent: some View {
        let _ = appState.analytics.update(for: completedSessions)
        let a = appState.analytics
        let signature = TrainingSignature(volume: a.volume, development: a.development.intensities, consistency: a.consistency)

        return ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    SignatureSection(signature: signature, report: a.consistency)
                        .settleIn(0)
                    GroupSeparator()
                    StrengthTrajectorySection(board: a.strength, progress: a.progress)
                        .settleIn(1)
                    GroupSeparator()
                    ExerciseDominanceSection(board: a.dominance)
                        .settleIn(2)
                    GroupSeparator()
                    IntensityMixSection(mix: a.intensity)
                        .settleIn(3)
                    GroupSeparator()
                    RepRangeMigrationSection(report: a.migration)
                        .settleIn(4)
                    GroupSeparator()
                    MovementCompositionSection(split: a.composition)
                        .settleIn(5)
                    GroupSeparator()
                    ConsistencySection(report: a.consistency)
                        .settleIn(6)
                    GroupSeparator()
                    TrainingLoadSection(report: a.load)
                        .settleIn(7)
                    GroupSeparator()
                    SymmetrySection(board: a.symmetry)
                        .settleIn(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No training logged yet",
            systemImage: "chart.xyaxis.line",
            description: Text("Once you complete a few workouts, this tab reads back the shape of your training, what to train next, and where your strength is heading.")
        )
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsScreen(appState: AppState())
            .navigationTitle("Insights")
    }
    .preferredColorScheme(.dark)
}
