//
//  InsightsScreen.swift
//  vivobody
//
//  The Insights tab, structured as four movements rather than a wall
//  of lookalike bars:
//
//    1. Signature — the generative hero: one mark for the whole shape
//       of your training (no body here; the 3D figure is Today's).
//    2. Train next — the verdict: a short, ranked list fusing volume,
//       momentum, and forecast into "what should I train?", with the
//       full per-muscle breakdown one tap away.
//    3. Strength — an estimated-1RM line chart per lift, a record line
//       to chase (Swift Charts, not bars).
//    4. Rhythm — the consistency heatmap plus a weekly-volume curve,
//       closed by the symmetry coda.
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
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if completedSessions.isEmpty {
                    emptyState
                } else {
                    let stats = completedSessions.muscleVolume()
                    // One development-model replay feeds every muscle
                    // instrument on the tab.
                    let modelState = MuscleDevelopment.simulate(from: completedSessions)
                    let momentum = modelState.muscleMomentum()
                    let forecast = modelState.muscleForecast()
                    let tightness = modelState.muscleTightness()
                    let strength = completedSessions.strengthOutlook()
                    let progress = completedSessions.progressByExercise
                    let symmetry = completedSessions.antagonistBalance()
                    let consistency = completedSessions.consistency()
                    let intensity = completedSessions.intensityMix()
                    let load = completedSessions.trainingLoad()
                    let signature = TrainingSignature(volume: stats, momentum: momentum, consistency: consistency)
                    let plan = TrainNextPlan(volume: stats, momentum: momentum, forecast: forecast)

                    SignatureSection(signature: signature, report: consistency)
                        .settleIn(0)
                    groupSeparator
                    TrainNextSection(plan: plan, stats: stats, momentum: momentum, forecast: forecast, tightness: tightness)
                        .settleIn(1)
                    groupSeparator
                    StrengthTrajectorySection(board: strength, progress: progress)
                        .settleIn(2)
                    groupSeparator
                    IntensityMixSection(mix: intensity)
                        .settleIn(3)
                    groupSeparator
                    ConsistencySection(report: consistency)
                        .settleIn(4)
                    groupSeparator
                    TrainingLoadSection(report: load)
                        .settleIn(5)
                    groupSeparator
                    SymmetrySection(board: symmetry)
                        .settleIn(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .forgeBackground()
    }

    // MARK: - Group separator

    private var groupSeparator: some View {
        SectionDivider()
            .padding(.vertical, Space.xxl)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Insights")
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("No training logged yet")
                    .sectionHeadingStyle()
                Text("Once you complete a few workouts, this tab reads back the shape of your training, what to train next, and where your strength is heading.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.sm)
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsScreen(appState: AppState())
            .navigationTitle("Insights")
    }
    .preferredColorScheme(.dark)
}
