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
    /// The SwiftData container. Holds every archived workout. The
    /// schema declares all @Model classes; cascade-delete
    /// relationships keep exercises and sets bound to their session.
    ///
    /// The app is still pre-production, so it has one current schema and one
    /// neutral development store. Model-breaking changes reset development
    /// data rather than accumulating migration versions before persistence
    /// ships as a product contract.
    ///
    /// Nil only when both the on-disk store and the in-memory fallback
    /// fail — in that case `body` presents a recovery view instead of
    /// crashing.
    private let container: ModelContainer? = {
        do {
            return try VivobodyStore.makeContainer(
                named: "vivobody",
                isStoredInMemoryOnly: false
            )
        } catch {
            AppDiagnostics.storageFallbackAttempt(error: error)
            // A failed on-disk store open must not crash every launch.
            // Fall back to an in-memory store so the app stays usable;
            // the original store is left untouched on disk for recovery.
            StorageHealth.shared.didFallbackToInMemory = true
            do {
                let memory = try VivobodyStore.makeContainer(
                    named: "vivobody-fallback",
                    isStoredInMemoryOnly: true
                )
                AppDiagnostics.storageFallbackSucceeded()
                return memory
            } catch {
                AppDiagnostics.storageUnavailable(error: error)
            }
            // Even the in-memory fallback failed — return nil so the
            // app can show a recovery view instead of crash-to-black.
            return nil
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let container {
                AppRoot()
                    .warmUpKeyboardOnce()
                #if DEBUG
                    .task {
                        if CommandLine.arguments.contains("--seed-history") {
                            HistorySeeder.seed(into: container.mainContext)
                        } else if CommandLine.arguments.contains("--seed-showcase") {
                            HistorySeeder.seedShowcase(into: container.mainContext)
                        } else if CommandLine.arguments.contains("--seed-pr") {
                            HistorySeeder.seedPRProximity(into: container.mainContext)
                        } else if CommandLine.arguments.contains("--seed-templates") {
                            HistorySeeder.seedTemplates(into: container.mainContext)
                        }
                    }
                #endif
                    .modelContainer(container)
            } else {
                StorageRecoveryView()
            }
        }
    }
}

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
