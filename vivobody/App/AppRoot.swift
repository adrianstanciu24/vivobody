//
//  AppRoot.swift
//  vivobody
//
//  Top-level container. Presents the process-wide AppState (tab selection +
//  Spotlight presentation) that VivobodyApp creates, and wires together three
//  native iOS 26 chrome elements:
//
//    1. Five-tab TabView with Tab(…) — Liquid Glass floating tab bar, large
//       per-tab nav titles, minimize-on-scroll behavior.
//    2. .tabViewBottomAccessory — the MiniBar pill that sits above
//       the tab bar whenever a workout is running. Tapping it expands
//       the workout back to the full screen. Inspired by Music's
//       MiniPlayer. Suppressed on Today, where the pinned CTA itself
//       becomes the resume control rather than stacking a third bar.
//    3. .sheet(isPresented:) — the focused ActiveWorkoutScreen
//       when the workout is expanded. Presented as a .large sheet
//       with a grabber so swipe-down minimizes it back to the MiniBar
//       (Music-style). Hides the tab bar while expanded.
//
//  Session lifetime vs. presentation lifetime are intentionally
//  decoupled here: `workout.activeSession != nil` controls whether a
//  compact form of the workout exists at all; `workout.isWorkoutExpanded`
//  controls whether the full screen is presented. A workout can be
//  minimized and resumed any number of times before it's archived.
//
//  Every external entry point becomes an IncomingAction dispatched through
//  workout.handle(_:) — the single routing site. URL scheme, Handoff, and
//  Spotlight taps are parsed by IncomingActionParser; App Intents (widgets,
//  controls, Siri) arrive through AppIntentRouter, which AppRoot attaches once
//  the active workout is restored.
//

import CoreSpotlight
import Intents
import SwiftData
import SwiftUI
import VivoKit

private enum CatalogPreparationState {
    case preparing
    case ready
    case failed
}

struct AppRoot: View {
    let analyticsSnapshotStore: AnalyticsSnapshotStore
    let catalogReconciliationStore: CatalogReconciliationStore
    let spotlightIndexStore: SpotlightIndexStore
    private let router: AppIntentRouter

    init(
        analyticsSnapshotStore: AnalyticsSnapshotStore,
        catalogReconciliationStore: CatalogReconciliationStore,
        spotlightIndexStore: SpotlightIndexStore,
        appState: AppState,
        router: AppIntentRouter
    ) {
        self.analyticsSnapshotStore = analyticsSnapshotStore
        self.catalogReconciliationStore = catalogReconciliationStore
        self.spotlightIndexStore = spotlightIndexStore
        _appState = Bindable(appState)
        self.router = router
    }

    #if DEBUG
        init(previewContainer: ModelContainer) {
            analyticsSnapshotStore = AnalyticsSnapshotStore(
                modelContainer: previewContainer
            )
            catalogReconciliationStore = CatalogReconciliationStore(
                modelContainer: previewContainer
            )
            spotlightIndexStore = SpotlightIndexStore(
                modelContainer: previewContainer
            )
            let appState = AppState()
            _appState = Bindable(appState)
            router = AppIntentRouter(appState: appState, container: previewContainer)
        }
    #endif

    @Bindable private var appState: AppState
    @State private var catalogPreparationState: CatalogPreparationState =
        CatalogLaunchReconciler.requiresReconciliation() ? .preparing : .ready
    @State private var catalogPreparationAttempt = 0
    @State private var removedCatalogItemIDs: [UUID] = []
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

    /// First-launch gate. Onboarding is the window's root until this flips,
    /// so the main tab hierarchy cannot paint behind a later modal presentation.
    @AppStorage(SettingsKey.onboardingCompleted)
    private var onboardingCompleted: Bool = SettingsDefaults.onboardingCompleted

    var body: some View {
        Group {
            if !onboardingCompleted {
                OnboardingScreen(onStart: { onboardingCompleted = true })
            } else {
                switch catalogPreparationState {
                case .preparing:
                    CatalogPreparationView(hasFailed: false, onRetry: retryCatalogPreparation)
                case .ready:
                    mainApp
                case .failed:
                    CatalogPreparationView(hasFailed: true, onRetry: retryCatalogPreparation)
                }
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .tint(Tint.primary)
        .environment(\.sessionAnalytics, appState.analytics)
        .task(id: catalogPreparationAttempt) {
            await prepareCatalogIfNeeded()
        }
    }

    private var mainApp: some View {
        @Bindable var workout = appState.workout

        return tabView
            // The one archive analytics feeder in the app. Its ModelActor
            // store resolves SwiftData changes before publishing values.
            .background(
                WorkoutInsightsFeeder(
                    appState: appState,
                    snapshotStore: analyticsSnapshotStore
                )
            )
            // One clock owns rest expiry while the workout is
            // minimized, since Today shows its pinned resume CTA and
            // every other tab shows the MiniBar — neither bar may own a
            // transition that has to fire exactly once.
            .background {
                if workout.activeSession != nil,
                   !workout.isDiscardPending,
                   !workout.isWorkoutExpanded
                {
                    RestExpiryTicker(workout: workout)
                }
            }
            .tabViewBottomAccessory(isEnabled: miniBarSession(workout) != nil) {
                if let session = miniBarSession(workout) {
                    ActiveWorkoutMiniBar(session: session, onExpand: { workout.expandWorkout() })
                }
            }
            .saveErrorAlert($workout.lastSaveError)
            .reviewRequestPresenter()
            .overlay(alignment: .top) {
                if appState.storageFallbackActive {
                    StorageFallbackBanner()
                }
            }
            .onAppear {
                // Wire the UI context, restore any in-flight workout (MiniBar),
                // and attach the intent router so queued App Intent actions
                // run. Catalog reconciliation has already committed through
                // CatalogReconciliationStore.
                appState.storageFallbackActive = StorageHealth.shared.didFallbackToInMemory
                WidgetSnapshotWriter.configure(analytics: appState.analytics)
                WidgetSnapshotWriter.configure(
                    snapshotStore: analyticsSnapshotStore
                )
                WidgetSnapshotWriter.removeRetiredKeys()
                if workout.modelContext == nil {
                    workout.modelContext = modelContext
                }
                #if DEBUG
                    let debugRoute = UITestSupport.route()
                #endif
                #if DEBUG
                    let launchActions = DebugSeedCoordinator.seedLaunchFixtures(
                        debugRoute.launchSteps,
                        in: modelContext
                    )
                    for action in launchActions {
                        router.perform(action)
                    }
                    if debugRoute.resetRequest != nil || !debugRoute.launchSteps.isEmpty {
                        // A reset can replace history with the same count and
                        // completion high-water mark. Reject any report the
                        // feeder started from the pre-seed archive.
                        appState.analytics.invalidate()
                    }
                    if let requestedTab = debugRoute.requestedTab {
                        appState.selectedTab = requestedTab
                    }
                #endif
                workout.restoreActiveWorkoutIfNeeded()
                AppearanceSideEffects.sync(appearance)
                router.attach()

                let catalogItemIDsToRemove = removedCatalogItemIDs
                removedCatalogItemIDs.removeAll()

                // This call only performs its cheap fingerprint check and
                // schedules the writer's existing coalesced publication.
                WidgetSnapshotWriter.writeAllIfStale(in: modelContext)
                SpotlightIndexer.scheduleLaunchMaintenance(
                    removing: catalogItemIDsToRemove,
                    store: spotlightIndexStore
                )
            }
            .onChange(of: scenePhase) { oldPhase, phase in
                if phase == .active {
                    WidgetSnapshotWriter.writeAllIfStale(in: modelContext)
                    RestNotificationController.cancelPending()
                } else if oldPhase == .active, workout.activeSession != nil {
                    // Force the latest in-memory scrub value to disk and
                    // publish Live Activity state before suspension.
                    workout.saveActiveSessionChanges()
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
            .sheet(
                isPresented: $workout.isWorkoutExpanded,
                onDismiss: { workout.finalizePendingDiscard() }
            ) {
                if let session = workout.activeSession {
                    ActiveWorkoutScreen(
                        session: session,
                        onDismiss: { workout.dismissActiveWorkout() },
                        onDiscard: { workout.discardActiveWorkout() },
                        onSessionUpdate: {
                            workout.saveActiveSessionChanges(for: session.id)
                        },
                        onScrubEnded: {
                            workout.saveSettledScrub(for: session.id)
                        },
                        onCompleteSet: { request, performMutation in
                            workout.completeActiveSet(
                                request,
                                performMutation: performMutation
                            )
                        },
                        onReplaceExercise: { exerciseID, item in
                            let result = workout.replacePendingExercise(
                                sessionID: session.id,
                                exerciseID: exerciseID,
                                with: item
                            )
                            let error: SaveErrorBox?
                            if result == .saveFailed {
                                error = workout.lastSaveError
                                workout.lastSaveError = nil
                            } else {
                                error = nil
                            }
                            return ExerciseSubstitutionCommit(
                                result: result,
                                saveError: error
                            )
                        },
                        onRemoveExercise: { exerciseID in
                            workout.removeExercise(
                                sessionID: session.id,
                                exerciseID: exerciseID
                            )
                        }
                    )
                    .presentationDetents([.large])
                    // The PR moment is accessibility-modal as well as visual:
                    // remove the system grabber so it cannot become a second
                    // VoiceOver dismissal target while the celebration owns
                    // the sheet. Resting workouts remain minimizable.
                    .presentationDragIndicator(
                        session.pendingPRValue == nil ? .visible : .hidden
                    )
                }
            }
            .sheet(item: $appState.pendingSpotlightExercise) { item in
                NavigationStack {
                    ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
                }
                .presentationDragIndicator(.visible)
            }
    }

    private func prepareCatalogIfNeeded() async {
        guard catalogPreparationState != .ready else { return }

        do {
            let store = catalogReconciliationStore
            // The model actor serializes its context, but a direct await can
            // still execute its synchronous transaction on the calling thread.
            let result = try await Task.detached(priority: .userInitiated) {
                try await store.reconcile()
            }.value
            removedCatalogItemIDs = result.removedItemIDs
            catalogPreparationState = .ready
        } catch {
            AppDiagnostics.catalogReconciliationFailed(error: error)
            catalogPreparationState = .failed
        }
    }

    private func retryCatalogPreparation() {
        catalogPreparationState = .preparing
        catalogPreparationAttempt &+= 1
    }

    /// The session the accessory pill should render, if any. Today owns
    /// the active workout itself: its pinned CTA becomes "Resume
    /// Workout" so the screen never stacks a start bar, a pill, and the
    /// tab bar into three rows of chrome. Every other tab keeps the
    /// pill as its way back into the workout.
    private func miniBarSession(_ workout: WorkoutSessionController) -> WorkoutSession? {
        guard !workout.isDiscardPending, appState.selectedTab != .today else { return nil }
        return workout.activeSession
    }

    private var tabView: some View {
        TabView(selection: $appState.selectedTab) {
            Tab(AppTab.today.label,
                systemImage: AppTab.today.icon,
                value: AppTab.today)
            {
                NavigationStack {
                    TodayScreen(appState: appState)
                        .navigationTitle("Today")
                }
            }

            Tab(AppTab.history.label,
                systemImage: AppTab.history.icon,
                value: AppTab.history)
            {
                NavigationStack {
                    HistoryScreen(appState: appState)
                        .navigationTitle("History")
                }
            }

            Tab(AppTab.library.label,
                systemImage: AppTab.library.icon,
                value: AppTab.library)
            {
                NavigationStack {
                    LibraryScreen(appState: appState)
                        .navigationTitle("Library")
                        .navigationBarTitleDisplayMode(.large)
                }
            }

            Tab(AppTab.insights.label,
                systemImage: AppTab.insights.icon,
                value: AppTab.insights)
            {
                NavigationStack {
                    InsightsScreen(appState: appState)
                        .navigationTitle("Insights")
                }
            }

            Tab(AppTab.me.label,
                systemImage: AppTab.me.icon,
                value: AppTab.me)
            {
                NavigationStack {
                    MeScreen(appState: appState)
                        .navigationTitle("Me")
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

// MARK: - Rest expiry clock

/// Sleeps until the current rest deadline, then asks the controller to end
/// the rest. Mounted zero-size in the shell so expiry fires behind whichever
/// bottom bar the selected tab happens to show. An extended rest changes the
/// deadline, which restarts the task.
private struct RestExpiryTicker: View {
    let workout: WorkoutSessionController

    var body: some View {
        let deadline = workout.activeSession?.restDeadline
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: deadline) {
                guard let deadline else { return }
                // Loop because a sleep can return slightly before the
                // deadline, and the task would not run again for this id.
                while !Task.isCancelled {
                    let remaining = deadline.timeIntervalSinceNow
                    if remaining <= 0 {
                        workout.endExpiredRestIfNeeded()
                        return
                    }
                    try? await Task.sleep(for: .seconds(remaining))
                }
            }
            .accessibilityHidden(true)
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

#if DEBUG
    #Preview {
        let configuration = ModelConfiguration(
            schema: VivobodyStore.schema,
            isStoredInMemoryOnly: true
        )
        let container = try! ModelContainer(
            for: VivobodyStore.schema,
            configurations: [configuration]
        )
        AppRoot(previewContainer: container)
            .modelContainer(container)
            .preferredColorScheme(.dark)
    }
#endif
