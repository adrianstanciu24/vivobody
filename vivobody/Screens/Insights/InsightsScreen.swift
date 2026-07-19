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
//  Free-tier users see this exact same sequence and spacing, frozen
//  beneath one frameless frosted layer per major section. No paywall
//  cards or labels alter the content layout; a single persistent
//  unlock control carries the purchase action.
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

    /// The user's real insights, each frozen beneath its own frosted
    /// cover. Its layout is identical to the unlocked screen: no
    /// inserted introduction, padding, card shape, or Pro labels.
    /// Every frozen section opens the shared purchase sheet, and one
    /// persistent control carries the only explicit CTA. Never shown
    /// before the first workout (the empty state wins), and never as
    /// a popup anywhere else.
    private var lockedContent: some View {
        let _ = appState.analytics.update(for: completedSessions)
        let a = appState.analytics
        let signature = TrainingSignature(
            volume: a.volume,
            development: a.development.intensities,
            consistency: a.consistency
        )

        return ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                insightSections(analytics: a, signature: signature, locked: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            unlockControl
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.sm)
        }
    }

    private var unlockControl: some View {
        Button(action: requestUnlock) {
            HStack(spacing: Space.md) {
                Text("Unlock Vivobody Pro")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let price = appState.pro.displayPrice {
                    Text("· \(price)")
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .font(Typography.headline)
            .foregroundStyle(Tint.onAccent)
            .frame(minHeight: Space.tapMin)
            .padding(.horizontal, Space.xl)
            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.primary)
            .softElevation(radius: 14, y: 7, opacity: 0.42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlockButtonLabel)
        .accessibilityHint("Opens the Vivobody Pro purchase sheet")
    }

    private var unlockButtonLabel: String {
        if let price = appState.pro.displayPrice {
            return "Unlock Vivobody Pro, \(price)"
        }
        return "Unlock Vivobody Pro"
    }

    private func requestUnlock() {
        appState.pro.requestUnlock()
    }

    private var loadedContent: some View {
        let _ = appState.analytics.update(for: completedSessions)
        let a = appState.analytics
        let signature = TrainingSignature(volume: a.volume, development: a.development.intensities, consistency: a.consistency)

        return ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                insightSections(analytics: a, signature: signature, locked: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    /// The one canonical section order for both entitlement states.
    /// Keeping the sequence shared means a future insight cannot be
    /// added to the unlocked screen while silently missing its Pro
    /// preview (or vice versa).
    @ViewBuilder
    private func insightSections(
        analytics a: SessionAnalytics,
        signature: TrainingSignature,
        locked: Bool
    ) -> some View {
        insightSection(title: "Your signature", index: 0, locked: locked) {
            SignatureSection(signature: signature, report: a.consistency)
        }
        insightSection(title: "Strength", index: 1, locked: locked) {
            StrengthTrajectorySection(board: a.strength, progress: a.progress)
        }
        insightSection(title: "Composition", index: 2, locked: locked) {
            ExerciseDominanceSection(board: a.dominance, split: a.composition)
        }
        insightSection(title: "Intensity", index: 3, locked: locked) {
            IntensityMixSection(
                mix: a.intensity,
                weeks: a.intensityWeeks,
                migration: a.migration
            )
        }
        insightSection(title: "Consistency", index: 4, locked: locked) {
            ConsistencySection(report: a.consistency)
        }
        insightSection(title: "Training load", index: 5, locked: locked) {
            TrainingLoadSection(report: a.load)
        }
        insightSection(title: "Symmetry", index: 6, locked: locked, isLast: true) {
            SymmetrySection(board: a.symmetry)
        }
    }

    @ViewBuilder
    private func insightSection<Content: View>(
        title: String,
        index: Int,
        locked: Bool,
        isLast: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if locked {
            LockedInsightPreview(
                title: title,
                action: requestUnlock,
                content: content
            )
            if !isLast {
                GroupSeparator()
            }
        } else {
            content()
                .settleIn(index)
            if !isLast {
                GroupSeparator()
            }
        }
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

// MARK: - Locked preview

/// One full Insights movement frozen in place beneath an interactive,
/// frameless frosted treatment. It adds no padding, shape, border, or
/// separate labels: the original header, timeframe, chart, and values
/// all receive the same blur and dimming. Accessibility sees only the
/// locked section, never the analytics hidden beneath it.
private struct LockedInsightPreview<Content: View>: View {
    let title: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        Button(action: action) {
            content()
                .blur(radius: reduceTransparency ? 0 : 8)
                .opacity(reduceTransparency ? 0 : 0.90)
                .accessibilityHidden(true)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title), locked")
        .accessibilityHint("Unlocks with Vivobody Pro")
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsScreen(appState: AppState())
            .navigationTitle("Insights")
    }
    .preferredColorScheme(.dark)
}
