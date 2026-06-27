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
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    let stats = completedSessions.muscleVolume()
                    // One development-model replay feeds the signature.
                    let modelState = MuscleDevelopment.simulate(from: completedSessions)
                    let strength = completedSessions.strengthOutlook()
                    let progress = completedSessions.progressByExercise
                    let dominance = completedSessions.exerciseDominance()
                    let intensity = completedSessions.intensityMix()
                    let migration = completedSessions.repRangeMigration()
                    let composition = completedSessions.compoundIsolationSplit()
                    let symmetry = completedSessions.antagonistBalance()
                    let consistency = completedSessions.consistency()
                    let load = completedSessions.trainingLoad()
                    let signature = TrainingSignature(volume: stats, development: modelState.intensities, consistency: consistency)

                    SignatureSection(signature: signature, report: consistency)
                        .settleIn(0)
                    GroupSeparator()
                    StrengthTrajectorySection(board: strength, progress: progress)
                        .settleIn(1)
                    GroupSeparator()
                    ExerciseDominanceSection(board: dominance)
                        .settleIn(2)
                    GroupSeparator()
                    IntensityMixSection(mix: intensity)
                        .settleIn(3)
                    GroupSeparator()
                    RepRangeMigrationSection(report: migration)
                        .settleIn(4)
                    GroupSeparator()
                    MovementCompositionSection(split: composition)
                        .settleIn(5)
                    GroupSeparator()
                    ConsistencySection(report: consistency)
                        .settleIn(6)
                    GroupSeparator()
                    TrainingLoadSection(report: load)
                        .settleIn(7)
                    GroupSeparator()
                    SymmetrySection(board: symmetry)
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
