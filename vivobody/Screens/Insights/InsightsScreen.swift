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
//    3. Composition — recent working-set allocation by exercise,
//       paired with a compound/isolation exercise-type split.
//    4. Intensity — 12 weeks of working sets stacked per week by
//       rep-range zone: the mix and its drift in one chart.
//    5. Rhythm — the consistency heatmap plus a weekly-volume curve.
//    6. Load — rolling hard-set equivalents against the user's
//       personal productive range, with the work that drove it.
//    7. Symmetry — the antagonist butterfly bars as the coda.
//
//  Every section is chart-first: the graphic leads at full size, one
//  caption line reads it, and the numbers ride the chart instead of
//  repeating it. This screen fetches the data, runs the value-type
//  models, and lays the movements out gutter-to-gutter with a
//  hairline between each. Visual language follows the rest of the
//  app: black, type-forward, the single orange accent for "on
//  target," danger-red only where something's slipping.
//

import VivoKit
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
            } else if appState.pro.isUnlocked {
                loadedContent
            } else {
                lockedContent
            }
        }
        .forgeBackground()
    }

    // MARK: - Locked state (free tier)

    /// The user's REAL insights, frozen behind frosted glass, with a
    /// single quiet unlock card floated on top. Their own symmetry
    /// chart is the pitch — not a feature list. Never shown before
    /// the first workout (the empty state wins), and never as a
    /// popup anywhere else in the app.
    private var lockedContent: some View {
        ZStack {
            loadedContent
                .blur(radius: 16)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Surface.background
                .opacity(0.45)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            unlockCard
                .padding(.horizontal, Space.gutter)
        }
    }

    private var unlockCard: some View {
        VStack(spacing: Space.lg) {
            Text("Vivobody Pro")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)

            Text("The full read on your training — signature, strength trajectory, symmetry, and where your lifts are heading. Built from the \(sessionCountLabel) you've already logged.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                appState.pro.requestUnlock()
            } label: {
                Text(unlockButtonLabel)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Unlock Vivobody Pro")

            Text("One-time purchase. Logging stays free forever.")
                .font(Typography.micro)
                .foregroundStyle(Ink.quaternary)
        }
        .padding(Space.xxl)
        .glassCard()
    }

    private var unlockButtonLabel: String {
        if let price = appState.pro.displayPrice {
            return "Unlock · \(price)"
        }
        return "Unlock"
    }

    private var sessionCountLabel: String {
        let count = completedSessions.count
        return count == 1 ? "workout" : "\(count) workouts"
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
                    ExerciseDominanceSection(board: a.dominance, split: a.composition)
                        .settleIn(2)
                    GroupSeparator()
                    IntensityMixSection(mix: a.intensity, weeks: a.intensityWeeks, migration: a.migration)
                        .settleIn(3)
                    GroupSeparator()
                    ConsistencySection(report: a.consistency)
                        .settleIn(4)
                    GroupSeparator()
                    TrainingLoadSection(report: a.load)
                        .settleIn(5)
                    GroupSeparator()
                    SymmetrySection(board: a.symmetry)
                        .settleIn(6)
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
