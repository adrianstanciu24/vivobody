//
//  InsightsScreen.swift
//  vivobody
//
//  Personal analytics as one ordered instrument scroll: Shape, Load, Rhythm, then
//  Balance. Each instrument keeps its own scope and dominant visual while
//  secondary distributions and the full balance roster live in drill-outs.
//  A wide, regular-width window lays the same cards in two lanes beside the
//  fold (InsightsCardLayout.swift); every other window keeps one column.
//  Free users see the same real-data instruments frozen beneath one shared
//  blur, while one persistent bottom action carries the purchase request.
//
import SwiftUI
import VivoKit

struct InsightsScreen: View {
    @Bindable var appState: AppState
    @Environment(\.appDisplayLayout) private var displayLayout

    var body: some View {
        Group {
            if !appState.analyticsArchiveHasSessions,
               appState.analytics.hasCoreReports
            {
                emptyState(hasArchivedWorkout: false)
            } else if let reports = appState.analytics.insightsReports {
                if !hasQualifyingData(reports) {
                    emptyState(hasArchivedWorkout: true)
                } else {
                    instrumentShell(reports: reports)
                }
            } else {
                loadingState
            }
        }
        .screenBackground()
        .toolbarBackground(Surface.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Instrument shell

    private func instrumentShell(
        reports: SessionAnalytics.InsightsReports
    ) -> some View {
        let pro = appState.pro
        let onUnlock: (() -> Void)? = pro.isUnlocked ? nil : { pro.requestUnlock() }
        return Group {
            if displayLayout.showsDashboardColumns, #available(iOS 27.1, *) {
                InsightsCardLanes(reports: reports, onUnlock: onUnlock)
            } else {
                ScrollView(.vertical) {
                    InsightsCardColumn(reports: reports)
                        .insightsLockedPreview(onUnlock: onUnlock)
                        .padding(.top, Space.lg)
                        .padding(.bottom, Space.xxl)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let onUnlock {
                ProUnlockButton(price: pro.displayPrice, action: onUnlock)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.sm)
            }
        }
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

            InsightsEmptyMark()
                .frame(width: 190, height: 150)
                .accessibilityHidden(true)

            VStack(spacing: Space.sm) {
                Text(hasArchivedWorkout ? "Nothing to read yet" : "No training logged yet")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("insightsEmptyState")

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
                subtitle: Text("Your next workout is one tap away"),
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
            InsightsEmptyMark(isLoading: true)
                .frame(width: 150, height: 118)
                .accessibilityHidden(true)
            ProgressView("Building your training signals")
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHint("Your training history is being analyzed")
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsScreen(appState: AppState())
            .navigationTitle("Insights")
    }
    .preferredColorScheme(.dark)
}
