//
//  AppRoot.swift
//  vivobody
//
//  Top-level container. Owns the AppState and wires together three
//  native iOS 26 chrome elements:
//
//    1. TabView with Tab(…) — Liquid Glass floating tab bar, large
//       per-tab nav titles, minimize-on-scroll behavior.
//    2. .tabViewBottomAccessory — the MiniBar pill that sits above
//       the tab bar whenever a workout is running. Tapping it expands
//       the workout back to the full screen. Inspired by Music's
//       MiniPlayer.
//    3. .sheet(isPresented:) — the focused ActiveWorkoutScreen
//       when the workout is expanded. Presented as a .large sheet
//       with a grabber so swipe-down minimizes it back to the MiniBar
//       (Music-style). Hides the tab bar while expanded.
//
//  Session lifetime vs. presentation lifetime are intentionally
//  decoupled here: `appState.activeSession != nil` controls whether the
//  MiniBar exists; `appState.isWorkoutExpanded` controls whether the
//  full screen is presented. A workout can be minimized and resumed
//  any number of times before it's archived.
//

import SwiftUI
import SwiftData

struct AppRoot: View {
    @State private var appState = AppState()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// The user's light/dark/system choice. Drives the whole window's
    /// color scheme (system resolving to nil so the OS decides).
    /// Applied at the top of the view tree so the navigation bar's
    /// large titles and the status bar recolor with it.
    @AppStorage(SettingsKey.appearance)
    private var appearanceRaw: String = SettingsDefaults.appearance

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        tabView
            .preferredColorScheme(appearance.colorScheme)
            .tint(Tint.primary)
            .miniBarAccessory(
                session: appState.activeSession,
                onExpand: { appState.expandWorkout() }
            )
            .saveErrorAlert($appState.lastSaveError)
            .onAppear {
                // Hand the SwiftData write context to AppState on
                // first appear. Subsequent appears are no-ops because
                // the reference doesn't change.
                if appState.modelContext == nil {
                    appState.modelContext = modelContext
                }
#if DEBUG
                UITestSupport.resetIfRequested(in: modelContext)
#endif
                // Seed the exercise catalog on a brand-new install.
                // Idempotent — bails if anything's already there, so
                // re-runs after migrations are cheap.
                ExerciseCatalogItem.seedIfEmpty(in: modelContext)
#if DEBUG
                UITestSupport.seedIfRequested(in: modelContext)
#endif
                ExerciseCatalogItem.backfillCopiedExerciseIdentity(in: modelContext)
                appState.restoreActiveWorkoutIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, appState.activeSession != nil {
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $appState.isWorkoutExpanded) {
                if let session = appState.activeSession {
                    ActiveWorkoutScreen(
                        session: session,
                        onDismiss: { appState.dismissActiveWorkout() },
                        onDiscard: { appState.discardActiveWorkout() }
                    )
                    // Music-style presentation: fills the screen, has
                    // a grabber for swipe-down-to-minimize, and leaves
                    // the presentation chrome to iOS 26's native glass —
                    // including the system's concentric sheet corner
                    // radius, so it stays in lockstep with the device's
                    // own curvature instead of a hardcoded value.
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
    }

    private var tabView: some View {
        TabView(selection: $appState.selectedTab) {
            Tab(AppTab.today.label,
                systemImage: AppTab.today.icon,
                value: AppTab.today) {
                NavigationStack {
                    TodayScreen(appState: appState)
                        .navigationTitle("Today")
                }
            }

            Tab(AppTab.history.label,
                systemImage: AppTab.history.icon,
                value: AppTab.history) {
                NavigationStack {
                    HistoryScreen(appState: appState)
                        .navigationTitle("History")
                }
            }

            Tab(AppTab.library.label,
                systemImage: AppTab.library.icon,
                value: AppTab.library) {
                NavigationStack {
                    LibraryScreen(appState: appState)
                        .navigationTitle("Library")
                }
            }

            Tab(AppTab.insights.label,
                systemImage: AppTab.insights.icon,
                value: AppTab.insights) {
                NavigationStack {
                    InsightsScreen(appState: appState)
                        .navigationTitle("Insights")
                }
            }

            Tab(AppTab.me.label,
                systemImage: AppTab.me.icon,
                value: AppTab.me) {
                NavigationStack {
                    MeScreen(appState: appState)
                        .navigationTitle("Me")
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

// MARK: - Conditional MiniBar accessory

/// Applies `.tabViewBottomAccessory` only when a session is active.
/// iOS 26's TabView reserves the accessory slot whenever the modifier
/// is attached — even with empty content — so the only reliable way
/// to hide the pill when there's no workout is to not apply the
/// modifier at all.
private extension View {
    @ViewBuilder
    func miniBarAccessory(
        session: WorkoutSession?,
        onExpand: @escaping () -> Void
    ) -> some View {
        if let session {
            self.tabViewBottomAccessory {
                ActiveWorkoutMiniBar(session: session, onExpand: onExpand)
            }
        } else {
            self
        }
    }
}

#Preview {
    AppRoot()
        .preferredColorScheme(.dark)
}
