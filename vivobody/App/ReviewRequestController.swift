//
//  ReviewRequestController.swift
//  vivobody
//
//  Owns the App Store review prompt — the only file that touches
//  StoreKit's review API. Subscribed to the session archive event in
//  SessionSideEffects.
//
//  Policy, deliberately simple: ask at most once, ever, and only
//  once the user has 20 archived workouts. The prompt then lands at
//  the calm moment right after a fully-logged session is closed with
//  Done — never at launch, never mid-workout. The system still
//  decides whether to render (3-per-365-day cap, never in TestFlight,
//  always in debug builds).
//

import StoreKit
import SwiftData
import UIKit

@MainActor
enum ReviewRequestController {
    /// Archived workouts required before the prompt can appear.
    static let requiredArchivedWorkouts = 20

    /// Called from SessionSideEffects on `.archived`, after the
    /// session's save has succeeded, so the just-finished workout is
    /// included in the count.
    static func requestReviewIfEligible(
        afterArchiving session: WorkoutSession,
        in context: ModelContext
    ) {
        // Done only appears for fully-logged sessions; bailing on a
        // half-finished workout never asks.
        guard session.isAllComplete else { return }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: SettingsKey.hasRequestedAppReview) else { return }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let archivedCount = (try? context.fetchCount(descriptor)) ?? 0
        guard archivedCount >= requiredArchivedWorkouts else { return }

        // Let the workout sheet come down before the system alert
        // appears over the app. The one-shot flag flips only when the
        // request is actually made — the API never reports whether
        // the prompt rendered.
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            defaults.set(true, forKey: SettingsKey.hasRequestedAppReview)
            AppStore.requestReview(in: scene)
        }
    }
}
