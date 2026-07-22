//
//  vivobodyApp.swift
//  vivobody
//
//  Created by Adrian Stanciu on 18.05.2026.
//

import SwiftUI
import SwiftData

@main
struct vivobodyApp: App {
    /// The SwiftData container. Holds every archived workout. The
    /// schema declares all three @Model classes; cascade-delete
    /// relationships keep exercises and sets bound to their session.
    /// Nil only when both the on-disk store and the in-memory fallback
    /// fail — in that case `body` presents a recovery view instead of
    /// crashing.
    private let container: ModelContainer? = {
        let schema = Schema(SchemaV3.models, version: SchemaV3.versionIdentifier)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: VivobodyMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            // A failed on-disk migration must not crash every launch.
            // Fall back to an in-memory store so the app stays usable;
            // the original store is left untouched on disk for recovery.
            StorageHealth.shared.didFallbackToInMemory = true
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let memory = try? ModelContainer(for: schema, migrationPlan: VivobodyMigrationPlan.self, configurations: [fallback]) {
                return memory
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

