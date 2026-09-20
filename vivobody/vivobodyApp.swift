//
//  vivobodyApp.swift
//  vivobody
//
//  App entry point. Creates the canonical SwiftData container with its
//  recoverable in-memory fallback, then installs AppRoot into the main scene.
//

import SwiftData
import SwiftUI

@main
struct VivobodyApp: App {
    private struct Dependencies {
        let container: ModelContainer
        let analyticsSnapshotStore: AnalyticsSnapshotStore
        let catalogReconciliationStore: CatalogReconciliationStore
        let spotlightIndexStore: SpotlightIndexStore
    }

    /// The SwiftData container. Holds every archived workout. The
    /// schema declares all @Model classes; cascade-delete
    /// relationships keep exercises and sets bound to their session.
    ///
    /// SchemaV1 is the first frozen persistence contract. Future model changes
    /// add a version and migration stage instead of replacing stored history.
    ///
    /// Nil only when both the on-disk store and the in-memory fallback
    /// fail — in that case `body` presents a recovery view instead of
    /// crashing.
    private let dependencies: Dependencies? = {
        do {
            let container = try VivobodyStore.makeContainer(
                named: "vivobody",
                isStoredInMemoryOnly: false
            )
            return Dependencies(
                container: container,
                analyticsSnapshotStore: AnalyticsSnapshotStore(
                    modelContainer: container
                ),
                catalogReconciliationStore: CatalogReconciliationStore(
                    modelContainer: container
                ),
                spotlightIndexStore: SpotlightIndexStore(
                    modelContainer: container
                )
            )
        } catch {
            AppDiagnostics.storageFallbackAttempt(error: error)
            // A failed on-disk store open must not crash every launch.
            // Fall back to an in-memory store so the app stays usable;
            // the original store is left untouched on disk for recovery.
            StorageHealth.shared.didFallbackToInMemory = true
            CatalogLaunchReconciler.invalidate()
            do {
                let memory = try VivobodyStore.makeContainer(
                    named: "vivobody-fallback",
                    isStoredInMemoryOnly: true
                )
                AppDiagnostics.storageFallbackSucceeded()
                return Dependencies(
                    container: memory,
                    analyticsSnapshotStore: AnalyticsSnapshotStore(
                        modelContainer: memory
                    ),
                    catalogReconciliationStore: CatalogReconciliationStore(
                        modelContainer: memory
                    ),
                    spotlightIndexStore: SpotlightIndexStore(
                        modelContainer: memory
                    )
                )
            } catch {
                AppDiagnostics.storageUnavailable(error: error)
            }
            // Even the in-memory fallback failed — return nil so the
            // app can show a recovery view instead of crash-to-black.
            return nil
        }
    }()

    init() {
        #if DEBUG
            // AppRoot reads this default while it initializes. Store mutation
            // belongs to DebugLaunchRoot's explicit bootstrap phase instead of
            // blocking the application initializer and its first frame.
            DebugStoreResetter.prepareDefaults(
                ifRequested: UITestSupport.route().resetRequest
            )
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies {
                #if DEBUG
                    DebugLaunchRoot(
                        analyticsSnapshotStore: dependencies.analyticsSnapshotStore,
                        catalogReconciliationStore: dependencies.catalogReconciliationStore,
                        spotlightIndexStore: dependencies.spotlightIndexStore
                    )
                    .modelContainer(dependencies.container)
                #else
                    AppRoot(
                        analyticsSnapshotStore: dependencies.analyticsSnapshotStore,
                        catalogReconciliationStore: dependencies.catalogReconciliationStore,
                        spotlightIndexStore: dependencies.spotlightIndexStore
                    )
                    .modelContainer(dependencies.container)
                #endif
            } else {
                StorageRecoveryView()
            }
        }
    }
}

#if DEBUG
    /// Keeps deterministic reset and manual-fixture work out of App.init and
    /// completes it before any tappable product surface is mounted. Explicit
    /// heavy fixtures can delay this bootstrap state, but can never starve an
    /// already-visible onboarding or tab interaction.
    private struct DebugLaunchRoot: View {
        let analyticsSnapshotStore: AnalyticsSnapshotStore
        let catalogReconciliationStore: CatalogReconciliationStore
        let spotlightIndexStore: SpotlightIndexStore

        @Environment(\.modelContext) private var modelContext
        @State private var isPrepared: Bool

        private let route: UITestRoute

        init(
            analyticsSnapshotStore: AnalyticsSnapshotStore,
            catalogReconciliationStore: CatalogReconciliationStore,
            spotlightIndexStore: SpotlightIndexStore
        ) {
            self.analyticsSnapshotStore = analyticsSnapshotStore
            self.catalogReconciliationStore = catalogReconciliationStore
            self.spotlightIndexStore = spotlightIndexStore
            let route = UITestSupport.route()
            self.route = route
            _isPrepared = State(initialValue: route.resetRequest == nil && route.manualFixture == nil)
        }

        var body: some View {
            Group {
                if isPrepared {
                    AppRoot(
                        analyticsSnapshotStore: analyticsSnapshotStore,
                        catalogReconciliationStore: catalogReconciliationStore,
                        spotlightIndexStore: spotlightIndexStore
                    )
                } else {
                    bootstrapPlaceholder
                }
            }
            .task {
                guard !isPrepared else { return }
                // Let the lightweight bootstrap state reach the compositor
                // before deterministic fixture work begins.
                await Task.yield()
                DebugStoreResetter.reset(
                    ifRequested: route.resetRequest,
                    in: modelContext
                )
                DebugSeedCoordinator.seedManualFixture(
                    route.manualFixture,
                    in: modelContext
                )
                isPrepared = true
            }
        }

        private var bootstrapPlaceholder: some View {
            ProgressView("Preparing preview data")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .screenBackground()
        }
    }
#endif

// MARK: - Recovery view

/// Shown when both the on-disk store and the in-memory fallback fail
/// to initialize. Gives the user a clear explanation and a relaunch
/// button instead of a crash-to-black screen.
private struct StorageRecoveryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.fill.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Storage couldn't be opened")
                    .font(.title2.bold())
                Text("Vivobody couldn't access its data store. Try restarting the app. If the problem persists, reinstalling may be necessary.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button {
                if let url = URL(string: "vivobody://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Relaunch")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
