//
//  InsightsScreen.swift
//  vivobody
//
//  The Insights tab. It composes a stack of independent instrument
//  components — Muscle Balance, Momentum, Forecast, Strength,
//  Symmetry, Consistency, and Training DNA — each living in its own
//  file and each responsible for its own copy, colours, and bars.
//  This screen's only jobs are to fetch the data, run the value-type
//  models over it, and lay the sections out gutter-to-gutter with a
//  hairline between each.
//
//  Every section fills the container width natively (`maxWidth:
//  .infinity`), and every bar reads its own width from the layout, so
//  the whole screen flexes to any device with no fixed widths.
//
//  Visual language follows the rest of the app: black, type-forward,
//  hairline dividers, the single orange accent reserved for the "on
//  target" state; danger-red only where something has overshot.
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

    /// Body-weight log — the latest entry sets the load for unloaded
    /// movements when the development model scores momentum (push-ups,
    /// pull-ups, planks), matching the 3D body on Today.
    @Query private var bodyWeights: [BodyWeightEntry]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if completedSessions.isEmpty {
                    emptyState
                } else {
                    let stats = completedSessions.muscleVolume()
                    let bodyweight = bodyWeights.latest?.weight ?? ExerciseLoad.defaultBodyweight
                    let momentum = completedSessions.muscleMomentum(bodyweight: bodyweight)
                    let forecast = completedSessions.muscleForecast(bodyweight: bodyweight)
                    let strength = completedSessions.strengthOutlook()
                    let symmetry = completedSessions.antagonistBalance()
                    let consistency = completedSessions.consistency()
                    let signature = TrainingSignature(volume: stats, momentum: momentum, consistency: consistency)

                    MuscleBalanceSection(stats: stats)
                    groupSeparator
                    MomentumSection(board: momentum)
                    groupSeparator
                    ForecastSection(board: forecast)
                    groupSeparator
                    StrengthSection(board: strength)
                    groupSeparator
                    SymmetrySection(board: symmetry)
                    groupSeparator
                    ConsistencySection(report: consistency)
                    groupSeparator
                    TrainingDNASection(signature: signature)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
    }

    // MARK: - Group separator

    private var groupSeparator: some View {
        SectionDivider()
            .padding(.vertical, Space.xl)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Muscle balance")
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("No training logged yet")
                    .sectionHeadingStyle()
                Text("Once you complete a few workouts, this shows how your effective sets spread across every muscle — and flags the ones falling behind.")
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
