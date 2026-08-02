//
//  AppState.swift
//  vivobody
//
//  Shell-only concerns:
//    • which of the five tabs is selected
//    • Spotlight-driven exercise detail presentation
//
//  Workout lifecycle (start / discard / dismiss / restore / minimize
//  / expand) lives in WorkoutSessionController, accessed via
//  `appState.workout`. Persistent history is owned by SwiftData and
//  queried directly by views via @Query.
//

import SwiftUI
import SwiftData
import Observation

enum AppTab: String, CaseIterable, Hashable {
    case today, history, library, insights, me

    var label: String {
        switch self {
        case .today:    return "Today"
        case .history:  return "History"
        case .library:  return "Library"
        case .insights: return "Insights"
        case .me:       return "Me"
        }
    }

    var icon: String {
        switch self {
        case .today:    return "calendar"
        case .history:  return "clock.arrow.circlepath"
        case .library:  return "books.vertical.fill"
        case .insights: return "chart.bar.fill"
        case .me:       return "person.fill"
        }
    }
}

@MainActor
@Observable
final class AppState {
    /// Which tab is selected.
    var selectedTab: AppTab = .today

    /// Lightweight archive presence published by the one canonical
    /// AnalyticsFeeder query. Insights uses this instead of mounting a
    /// second SwiftData query at the top of a pushed destination.
    var analyticsArchiveHasSessions = false

    /// Catalog item surfaced by a Spotlight search-result tap,
    /// presented as a detail sheet from the app shell. Nil when no
    /// Spotlight-driven detail is pending; the sheet binding clears
    /// it on dismiss.
    var pendingSpotlightExercise: ExerciseCatalogItem? = nil

    /// True when the on-disk SwiftData store couldn't be opened and
    /// the app is running on an in-memory fallback. AppRoot shows a
    /// warning banner so the user knows nothing is being saved.
    var storageFallbackActive: Bool = false

    /// The workout session controller. Owns activeSession,
    /// isWorkoutExpanded, lastSaveError, and all lifecycle methods.
    let workout = WorkoutSessionController()

    /// Shared two-tier analytics cache. General surfaces refresh core
    /// reports; Insights explicitly materializes its deeper tier. The
    /// fingerprint skips both when the dataset has not changed.
    let analytics = SessionAnalytics()

    /// The Pro entitlement store — the app's single StoreKit
    /// boundary. Screens read `pro.status` to gate the depth layer
    /// and call `pro.requestUnlock()` to present the shared paywall
    /// sheet (bound in AppRoot).
    let pro = ProStore()

    init() {
        workout.appState = self
    }

    /// Present a catalog item's detail as a modal sheet, driven by a
    /// Spotlight search-result tap. Routed through AppState so the
    /// shell owns presentation, independent of the Library tab's
    /// lifecycle.
    func presentSpotlightExercise(_ item: ExerciseCatalogItem) {
        pendingSpotlightExercise = item
    }

    func presentInsights() {
        selectedTab = .insights
    }
}
