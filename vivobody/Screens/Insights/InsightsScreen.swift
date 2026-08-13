//
//  InsightsScreen.swift
//  vivobody
//
//  Personal analytics tab. The detailed visual instruments begin
//  immediately in decision order: signature, load, composition,
//  rep ranges, consistency, and training balance. Per-exercise strength
//  curves live with their exercise in Library.
//
//  Free-tier users see the same sequence and spacing, frozen beneath
//  a frameless blur. No replacement paywall card alters the content;
//  one persistent bottom control carries the purchase action.
//

import VivoKit
import SwiftUI

struct InsightsScreen: View {
    @Bindable var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        Group {
            if !appState.analyticsArchiveHasSessions,
               appState.analytics.hasCoreReports {
                emptyState(hasArchivedWorkout: false)
            } else if let reports = appState.analytics.insightsReports {
                if !hasQualifyingData(reports) {
                    emptyState(hasArchivedWorkout: true)
                } else if appState.pro.isUnlocked {
                    loadedContent(reports)
                } else {
                    lockedContent(reports)
                }
            } else {
                loadingState
            }
        }
        .screenBackground()
    }

    // MARK: - Loaded state

    private func loadedContent(
        _ reports: SessionAnalytics.InsightsReports
    ) -> some View {
        let signature = TrainingSignature(
            volume: reports.core.volume,
            groupVolume: reports.core.groupVolume,
            cadence: reports.core.overview.averageWorkoutsPerWeek
        )

        return ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                insightSections(
                    reports: reports,
                    signature: signature,
                    locked: false
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    @ViewBuilder
    private func insightSections(
        reports: SessionAnalytics.InsightsReports,
        signature: TrainingSignature,
        locked: Bool
    ) -> some View {
        let core = reports.core
        let deep = reports.deep

        insightSection(title: "Your signature", index: 0, locked: locked) {
            SignatureSection(signature: signature)
        }
        insightSection(title: "Training load", index: 1, locked: locked) {
            TrainingLoadSection(report: core.load)
        }
        insightSection(title: "Strength composition", index: 2, locked: locked) {
            ExerciseDominanceSection(board: deep.dominance, split: deep.composition)
        }
        insightSection(title: "Rep ranges", index: 3, locked: locked) {
            IntensityMixSection(
                mix: deep.intensity,
                weeks: deep.intensityWeeks,
                migration: deep.migration
            )
        }
        insightSection(title: "Consistency", index: 4, locked: locked) {
            ConsistencySection(report: deep.consistency)
        }
        insightSection(
            title: "Training balance",
            index: 5,
            locked: locked,
            isLast: true
        ) {
            SymmetrySection(board: deep.symmetry)
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
        } else {
            content()
                .settleIn(index)
        }

        if !isLast {
            GroupSeparator()
        }
    }

    // MARK: - Locked state

    private func lockedContent(
        _ reports: SessionAnalytics.InsightsReports
    ) -> some View {
        let signature = TrainingSignature(
            volume: reports.core.volume,
            groupVolume: reports.core.groupVolume,
            cadence: reports.core.overview.averageWorkoutsPerWeek
        )

        return ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                insightSections(
                    reports: reports,
                    signature: signature,
                    locked: true
                )
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
            .font(Typography.title)
            .foregroundStyle(Tint.onAccent)
            .frame(minHeight: Space.rowMin)
            .padding(.horizontal, Space.xxl)
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

    // MARK: - Qualification and first use

    private func hasQualifyingData(
        _ reports: SessionAnalytics.InsightsReports
    ) -> Bool {
        reports.deep.consistency.hasActivity
            || reports.deep.dominance.hasAny
            || reports.deep.composition.totalSets > 0
            || reports.core.volume.contains { $0.allTimeEffectiveSets > 0 }
            || reports.core.load.currentLoad > 0
    }

    private func emptyState(hasArchivedWorkout: Bool) -> some View {
        VStack(spacing: Space.xl) {
            Spacer(minLength: Space.xxl)

            InsightEmptyMark()
                .frame(width: 190, height: 150)
                .accessibilityHidden(true)

            VStack(spacing: Space.sm) {
                Text(hasArchivedWorkout ? "Nothing to read yet" : "No training logged yet")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)

                Text(
                    hasArchivedWorkout
                        ? "Complete working sets in a new workout. Recent history with enough comparable work will bring the first signals into view."
                        : "Complete a workout and Insights will read back your load, rhythm, and training shape."
                )
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryActionButton(
                title: "Go to Today",
                subtitle: "Your next workout is one tap away",
                icon: "arrow.right"
            ) {
                appState.selectedTab = .today
            }

            Spacer(minLength: Space.xxl)
        }
        .padding(.horizontal, Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: Space.lg) {
            InsightEmptyMark(isLoading: true)
                .frame(width: 150, height: 118)
                .accessibilityHidden(true)
            ProgressView("Building your training signals")
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHint("Your training history is being analyzed")
    }

}

// MARK: - Locked preview

/// A full insight frozen in place beneath the old frameless frosted
/// treatment. The real section keeps its exact layout and spacing;
/// accessibility exposes only the purchase target, not hidden data.
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

private struct InsightEmptyMark: View {
    var isLoading = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Tint.primary.opacity(isLoading ? 0.20 : 0.13), .clear],
                center: .center,
                startRadius: 1,
                endRadius: 90
            )

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        index == 1
                            ? Tint.primary.opacity(isLoading ? 0.62 : 0.38)
                            : Ink.primary.opacity(0.13),
                        lineWidth: index == 1 ? 1.5 : 1
                    )
                    .frame(
                        width: 54 + CGFloat(index) * 34,
                        height: 112 - CGFloat(index) * 22
                    )
                    .rotationEffect(.degrees(Double(index - 1) * 31))
            }

            Circle()
                .fill(Tint.primary)
                .frame(width: 8, height: 8)
                .shadow(color: Tint.primary.opacity(0.78), radius: 9)
        }
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsScreen(appState: AppState())
            .navigationTitle("Insights")
    }
    .preferredColorScheme(.dark)
}
