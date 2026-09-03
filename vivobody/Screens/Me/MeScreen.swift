//
//  MeScreen.swift
//  vivobody
//
//  Personal-tab shell. Owns SwiftData queries, analytics readiness, AppState
//  navigation, sheet presentation, section order, and settle timing. One
//  immutable MePresentation feeds the focused dashboard sections.
//

import SwiftData
import SwiftUI
import VivoKit

struct MeScreen: View {
    @Bindable var appState: AppState

    /// One-row probe for the loading gate. Lifetime values come from the
    /// shared analytics overview rather than faulting the full archive here.
    @Query private var latestSessions: [WorkoutSession]

    /// Bounded newest-first input for the current value, latest delta, and
    /// compact sparkline. Presentation copies values out of SwiftData once.
    @Query private var bodyWeightEntries: [BodyWeightEntry]

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    @State private var logTarget: BodyWeightLogTarget?

    init(appState: AppState) {
        self.appState = appState

        var latest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        latest.fetchLimit = 1
        _latestSessions = Query(latest)

        var recentWeights = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        recentWeights.fetchLimit = MePresentation.bodyWeightLimit
        _bodyWeightEntries = Query(recentWeights)
    }

    private var hasHistory: Bool {
        latestSessions.first != nil
    }

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    private var presentation: MePresentation {
        MePresentation.make(
            hasHistory: hasHistory,
            hasCoreReports: appState.analytics.hasCoreReports,
            overview: appState.analytics.overview,
            standingRecords: appState.analytics.progress.standingRecords,
            bodyWeightSamplesNewestFirst: bodyWeightEntries.map {
                MePresentation.BodyWeightSample(
                    date: $0.date,
                    canonicalPounds: $0.weight
                )
            },
            unit: weightUnit
        )
    }

    var body: some View {
        ScrollView {
            switch presentation {
            case .loading:
                loadingState
            case let .dashboard(dashboard):
                dashboardContent(dashboard)
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Ink.secondary)
                }
                .tint(Ink.secondary)
                .accessibilityLabel("Settings")
            }
        }
        .sheet(item: $logTarget) { target in
            BodyWeightLogSheet(target: target)
        }
    }

    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.top, Space.xxl)
            .accessibilityLabel("Loading your training totals")
    }

    private func dashboardContent(
        _ dashboard: MePresentation.Dashboard
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MeJourneySection(presentation: dashboard.journey)
                .settleIn(0)

            GroupSeparator(verticalPadding: Space.lg)
            MeInsightsPortal(presentation: dashboard.insights) {
                appState.presentInsights()
            }
            .settleIn(1)

            GroupSeparator(verticalPadding: Space.lg)
            MeMilestonesSection(presentation: dashboard.milestones)
                .settleIn(2)

            if dashboard.records.hasRecords {
                GroupSeparator(verticalPadding: Space.lg)
                recordsSection(dashboard.records)
                    .settleIn(3)
            }

            GroupSeparator(verticalPadding: Space.lg)
            bodyWeightSection(dashboard.bodyWeight)
                .settleIn(dashboard.records.hasRecords ? 4 : 3)

            GroupSeparator(verticalPadding: Space.lg)
            MeMonthlyRecapSection(presentation: dashboard.recap)
                .settleIn(dashboard.records.hasRecords ? 5 : 4)
        }
        .padding(.top, Space.sm)
        .padding(.bottom, Space.section + Space.md)
    }

    private func recordsSection(
        _ records: MePresentation.Records
    ) -> some View {
        MeRecordsSection(presentation: records) {
            NavigationLink {
                PersonalRecordsScreen()
            } label: {
                SectionHeader(
                    title: "Personal records",
                    trailing: records.trailingLabel
                )
                .frame(minHeight: Space.tapMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens all personal records")
        }
    }

    private func bodyWeightSection(
        _ bodyWeight: MePresentation.BodyWeight
    ) -> some View {
        MeBodyWeightSection(
            presentation: bodyWeight,
            onLogWeight: {
                Haptics.soft()
                logTarget = .create
            }
        ) { populated in
            NavigationLink {
                BodyWeightDetail()
            } label: {
                MeBodyWeightPopulatedCard(presentation: populated)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens body weight details")
        }
    }
}

#Preview {
    NavigationStack {
        MeScreen(appState: AppState())
            .navigationTitle("Me")
    }
    .preferredColorScheme(.dark)
}
