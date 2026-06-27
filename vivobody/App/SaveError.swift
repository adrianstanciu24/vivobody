//
//  SaveError.swift
//  vivobody
//
//  Shared SwiftData save-failure handling. Two pieces:
//    • ModelContext.saveOrRollback() — wraps save() so a thrown
//      error rolls the context back to its last saved state before
//      rethrowing. Callers do/try/catch and decide how to surface it.
//    • SaveErrorBox + View.saveErrorAlert(_:) — an Identifiable
//      error wrapper and a reusable alert modifier so every editor
//      gets the same "couldn't save, your edits are kept" UX without
//      duplicating copy or alert wiring per screen.
//
//  The contract across the app: on a commit path (Save / Done /
//  dismiss), call saveOrRollback(); on success dismiss (or proceed),
//  on failure set a local `@State saveError: SaveErrorBox?` and stay
//  open so the user can retry or adjust. Non-user-facing best-effort
//  saves (seeders, catalog reset) may use `try? saveOrRollback()`.
//

import SwiftUI
import SwiftData

extension ModelContext {
    /// Save the context, rolling back to the last saved state on
    /// failure before rethrowing. Keeps partial mutations from
    /// poisoning the context for subsequent operations. `nonisolated`
    /// because `ModelContext` is not actor-bound — usable from both
    /// MainActor views and nonisolated model helpers.
    nonisolated func saveOrRollback() throws {
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}

/// Identifiable error wrapper for `.alert(item:)` / `.saveErrorAlert`.
/// Carries a single human-readable message derived from the error.
struct SaveErrorBox: Identifiable {
    let id = UUID()
    let message: String

    init(_ error: Error) {
        message = (error as? LocalizedError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

extension View {
    /// Standard save-failure alert. Binds to an optional
    /// `SaveErrorBox?`; when non-nil it presents a dismiss-only alert
    /// whose body is the error's message, then clears the binding on
    /// dismissal so the editor stays open for a retry.
    func saveErrorAlert(_ box: Binding<SaveErrorBox?>) -> some View {
        alert(
            "Couldn’t save",
            isPresented: Binding(
                get: { box.wrappedValue != nil },
                set: { if !$0 { box.wrappedValue = nil } }
            ),
            presenting: box.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { box.wrappedValue = nil }
        } message: { error in
            Text(error.message)
        }
    }
}
