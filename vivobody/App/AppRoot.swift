//
//  AppRoot.swift
//  vivobody
//
//  Top-level container. Owns the AppState (tab selection + Spotlight
//  presentation) and wires together three native iOS 26 chrome
//  elements:
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
//  decoupled here: `workout.activeSession != nil` controls whether the
//  MiniBar exists; `workout.isWorkoutExpanded` controls whether the
//  full screen is presented. A workout can be minimized and resumed
//  any number of times before it's archived.
//
//  Every external entry point (URL scheme, Handoff, Spotlight, widget
//  / Siri mailboxes) is parsed by IncomingActionParser into an
//  IncomingAction and dispatched through workout.handle(_:) — the
//  single routing site.
//

import VivoKit
import SwiftUI
import SwiftData
import Intents
import CoreSpotlight

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

    /// First-launch gate. Once true the welcome screen never shows
    /// again. The fullScreenCover binding is derived from its inverse
    /// so tapping Start (which sets this true) dismisses the cover.
    @AppStorage(SettingsKey.onboardingCompleted)
    private var onboardingCompleted: Bool = SettingsDefaults.onboardingCompleted

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !onboardingCompleted },
            set: { presented in onboardingCompleted = !presented }
        )
    }

    var body: some View {
        @Bindable var workout = appState.workout
        @Bindable var pro = appState.pro

        tabView
            .preferredColorScheme(appearance.colorScheme)
            .tint(Tint.primary)
            .miniBarAccessory(
                session: workout.activeSession,
                onExpand: { workout.expandWorkout() }
            )
            .saveErrorAlert($workout.lastSaveError)
            .overlay(alignment: .top) {
                if appState.storageFallbackActive {
                    StorageFallbackBanner()
                }
            }
            .onAppear {
                // Critical path — must complete before first paint:
                // wire the model context, seed the catalog if empty,
                // restore any in-flight workout (MiniBar), and drain
                // pending deep links.
                appState.storageFallbackActive = StorageHealth.shared.didFallbackToInMemory
                if workout.modelContext == nil {
                    workout.modelContext = modelContext
                }
#if DEBUG
                UITestSupport.resetIfRequested(in: modelContext)
#endif
                ExerciseCatalogItem.seedIfEmpty(in: modelContext)
#if DEBUG
                UITestSupport.seedIfRequested(in: modelContext)
#endif
                workout.restoreActiveWorkoutIfNeeded()
                consumeIncomingActions()

                // Non-critical path — defer to a low-priority Task so
                // SwiftUI's first render isn't blocked by legacy data
                // fix-ups, Spotlight indexing, or widget snapshot writes.
                Task(priority: .utility) { @MainActor in
                    ExerciseCatalogItem.backfillCopiedExerciseIdentityIfNeeded(in: modelContext)
                    let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
                    let items = (try? modelContext.fetch(FetchDescriptor<ExerciseCatalogItem>())) ?? []
                    SpotlightIndexer.reindexAllIfNeeded(templates: templates, items: items)
                    WidgetSnapshotWriter.writeAll(in: modelContext)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    consumeIncomingActions()
                    WidgetSnapshotWriter.writeAll(in: modelContext)
                    RestNotificationController.cancelPending()
                } else if workout.activeSession != nil {
                    do {
                        try modelContext.save()
                    } catch {
                        workout.lastSaveError = SaveErrorBox(error)
                    }
                    WidgetSnapshotWriter.writeActiveWorkout(in: modelContext)
                    RestNotificationController.scheduleIfResting(for: workout.activeSession)
                }
            }
            .onOpenURL { url in
                if let action = IncomingActionParser.from(url: url) {
                    workout.handle(action)
                }
            }
            .userActivity(
                ContinueWorkoutActivity.activityType,
                isActive: workout.activeSession != nil
            ) { activity in
                guard let session = workout.activeSession else { return }
                activity.title = ContinueWorkoutActivity.title(for: session)
                activity.suggestedInvocationPhrase = "Continue my workout"
                activity.isEligibleForHandoff = true
                activity.isEligibleForSearch = false
                activity.isEligibleForPrediction = true
                activity.isEligibleForPublicIndexing = false
                activity.requiredUserInfoKeys = Set([ContinueWorkoutActivity.sessionIDKey])
                activity.userInfo = ContinueWorkoutActivity.userInfo(for: session)
                activity.persistentIdentifier = session.id.uuidString
                activity.targetContentIdentifier = session.id.uuidString
            }
            .onContinueUserActivity(ContinueWorkoutActivity.activityType) { activity in
                if workout.modelContext == nil {
                    workout.modelContext = modelContext
                }
                if let action = IncomingActionParser.fromContinueActivity(activity) {
                    workout.handle(action)
                }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if workout.modelContext == nil {
                    workout.modelContext = modelContext
                }
                if let action = IncomingActionParser.fromSpotlightActivity(activity) {
                    workout.handle(action)
                }
            }
            .sheet(isPresented: $workout.isWorkoutExpanded) {
                if let session = workout.activeSession {
                    ActiveWorkoutScreen(
                        session: session,
                        onDismiss: { workout.dismissActiveWorkout() },
                        onDiscard: { workout.discardActiveWorkout() }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $appState.pendingSpotlightExercise) { item in
                NavigationStack {
                    ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $pro.isPaywallPresented) {
                PaywallSheet(pro: appState.pro)
            }
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingScreen(onStart: { onboardingCompleted = true })
            }
            .environment(\.sessionAnalytics, appState.analytics)
            .environment(appState.pro)
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

    /// Consume pending widget / Siri requests on launch and each
    /// foreground transition. Each parser clears its UserDefaults
    /// mailbox before returning; the handler no-ops if the action
    /// can't be processed (e.g., no active session for complete-set).
    private func consumeIncomingActions() {
        if let action = IncomingActionParser.fromWidgetStartRequest() {
            appState.workout.handle(action)
        }
        if let action = IncomingActionParser.fromTemplateStartRequest() {
            appState.workout.handle(action)
        }
        if let action = IncomingActionParser.fromCompleteSetRequest() {
            appState.workout.handle(action)
        }
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

// MARK: - Storage fallback banner

/// Shown when the on-disk store couldn't be opened and the app is
/// running in-memory. The user needs to know nothing is being saved.
private struct StorageFallbackBanner: View {
    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tint.danger)
            Text("Your data couldn't be opened. Nothing is being saved.")
                .font(Typography.caption)
                .foregroundStyle(Ink.primary)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity)
        .background(Tint.danger.opacity(0.12))
        .padding(.top, 4)
    }
}

#Preview {
    AppRoot()
        .preferredColorScheme(.dark)
}
