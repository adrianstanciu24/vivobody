//
//  ReviewRequestController.swift
//  vivobody
//
//  Owns the App Store review prompt — the only file that touches
//  StoreKit's review API. Subscribed to the session archive event in
//  SessionSideEffects; the presenter modifier installed at the app root
//  shows the prompt through SwiftUI's `requestReview` action.
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
import SwiftUI

@MainActor
enum ReviewRequestController {
    /// Archived workouts required before the prompt can appear.
    static let requiredArchivedWorkouts = 20

    fileprivate static let prompt = ReviewPrompt()

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

        guard !UserDefaults.standard.bool(forKey: SettingsKey.hasRequestedAppReview) else { return }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let archivedCount = (try? context.fetchCount(descriptor)) ?? 0
        guard archivedCount >= requiredArchivedWorkouts else { return }

        prompt.isPending = true
    }
}

@MainActor
@Observable
private final class ReviewPrompt {
    var isPending = false
}

extension View {
    /// Shows the App Store review prompt once ReviewRequestController
    /// finds the user eligible. Install once, at the app root.
    func reviewRequestPresenter() -> some View {
        modifier(ReviewRequestPresenter())
    }
}

private struct ReviewRequestPresenter: ViewModifier {
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        let prompt = ReviewRequestController.prompt
        return content.task(id: prompt.isPending) {
            guard prompt.isPending else { return }
            // Let the workout sheet come down before the system alert
            // appears over the app. The one-shot flag flips only when the
            // request is actually made — the API never reports whether
            // the prompt rendered.
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            prompt.isPending = false
            UserDefaults.standard.set(true, forKey: SettingsKey.hasRequestedAppReview)
            requestReview()
        }
    }
}
