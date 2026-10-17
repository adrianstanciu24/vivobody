//
//  IncomingAction.swift
//  vivobody
//
//  Unified representation of every external entry point into the app:
//  URL scheme, Handoff / NSUserActivity, Spotlight taps, and App Intents
//  (widgets, controls, Siri). URL, Handoff, and Spotlight sources each
//  have a tiny parser that returns an `IncomingAction`; App Intents build
//  the action directly and route it through AppIntentRouter. The
//  controller's `handle(_:)` is the single dispatch site.
//

import CoreSpotlight
import Foundation

enum IncomingAction: Equatable {
    /// Switch to a tab (URL scheme, generic deep link).
    case openTab(AppTab)
    /// Go to Today and expand the workout sheet if a session is active.
    case resumeWorkout
    /// Start today's workout, resolving the template from UpNext.
    case startTodaysWorkout
    /// Start a workout from a specific saved template.
    case startTemplate(UUID)
    /// Resume a specific session by UUID (Handoff / Siri Suggestion).
    case continueSession(UUID)
    /// Present a catalog exercise's detail as a modal sheet.
    case showExercise(UUID)
    /// Complete the active set on the current exercise (Live Activity tap).
    case completeActiveSet

    /// Privacy-safe case name for diagnostics. Associated UUIDs and other
    /// user-linked payloads deliberately never enter unified logs.
    var diagnosticKind: String {
        switch self {
        case .openTab: "open_tab"
        case .resumeWorkout: "resume_workout"
        case .startTodaysWorkout: "start_today"
        case .startTemplate: "start_template"
        case .continueSession: "continue_session"
        case .showExercise: "show_exercise"
        case .completeActiveSet: "complete_active_set"
        }
    }
}

// MARK: - Parsers

/// Each static method turns one inbound channel into an optional
/// `IncomingAction`. Returns nil when the signal is absent, stale, or
/// malformed — the caller no-ops on nil.
enum IncomingActionParser {
    // MARK: URL scheme

    /// `vivobody://today`, `vivobody://library`, `vivobody://insights`,
    /// `vivobody://workout`
    static func from(url: URL) -> IncomingAction? {
        guard url.scheme == "vivobody" else { return nil }
        let route = [url.host, url.path]
            .compactMap(\.self)
            .joined(separator: "")
        switch route {
        case "today", "":
            return .openTab(.today)
        case "insights", "insights/", "insights/consistency":
            return .openTab(.insights)
        case "library", "library/":
            return .openTab(.library)
        case "workout":
            return .resumeWorkout
        case "pro":
            // Older widget links now open the fully available Insights tab.
            return .openTab(.insights)
        default:
            return .openTab(.today)
        }
    }

    // MARK: Handoff / NSUserActivity

    /// Continue-workout activity (Handoff banner, Siri Suggestion).
    static func fromContinueActivity(_ activity: NSUserActivity) -> IncomingAction? {
        guard activity.activityType == ContinueWorkoutActivity.activityType else { return nil }
        guard let id = ContinueWorkoutActivity.sessionID(from: activity) else { return nil }
        return .continueSession(id)
    }

    // MARK: Spotlight

    /// Tap on a legacy CoreSpotlight item, whose uniqueIdentifier is
    /// `"template:<uuid>"` or `"exercise:<uuid>"`. Indexed entities route
    /// through their OpenIntents instead.
    static func fromSpotlightActivity(_ activity: NSUserActivity) -> IncomingAction? {
        guard activity.activityType == CSSearchableItemActionType else { return nil }
        guard let uniqueID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        let parts = uniqueID.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let uuid = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "template": return .startTemplate(uuid)
        case "exercise": return .showExercise(uuid)
        default: return nil
        }
    }
}
