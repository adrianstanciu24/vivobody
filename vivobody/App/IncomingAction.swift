//
//  IncomingAction.swift
//  vivobody
//
//  Unified representation of every external entry point into the app:
//  URL scheme, Handoff / NSUserActivity, Spotlight taps, and widget /
//  Siri UserDefaults mailboxes. Each source has a tiny parser that
//  returns an `IncomingAction`; the controller's `handle(_:)` is the
//  single dispatch site. New deep links or widget intents become one
//  case + one parser line.
//

import VivoKit
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
    /// Complete the active set on the current exercise (widget tap).
    case completeActiveSet
}

// MARK: - Parsers

/// Each static method turns one inbound channel into an optional
/// `IncomingAction`. Returns nil when the signal is absent, stale, or
/// malformed — the caller no-ops on nil.
enum IncomingActionParser {

    // MARK: URL scheme

    /// `vivobody://today`, `vivobody://insights`, `vivobody://workout`
    static func from(url: URL) -> IncomingAction? {
        guard url.scheme == "vivobody" else { return nil }
        let route = [url.host, url.path]
            .compactMap { $0 }
            .joined(separator: "")
        switch route {
        case "today", "":
            return .openTab(.today)
        case "insights", "insights/", "insights/consistency":
            return .openTab(.insights)
        case "workout":
            return .resumeWorkout
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

    /// Spotlight search-result tap. The indexed uniqueIdentifier is
    /// `"template:<uuid>"` or `"exercise:<uuid>"`.
    static func fromSpotlightActivity(_ activity: NSUserActivity) -> IncomingAction? {
        guard activity.activityType == CSSearchableItemActionType else { return nil }
        guard let uniqueID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        let parts = uniqueID.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let uuid = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "template":  return .startTemplate(uuid)
        case "exercise":  return .showExercise(uuid)
        default:          return nil
        }
    }

    // MARK: Widget / Siri UserDefaults mailboxes

    /// Widget "Start" tap — resolves the template from UpNext at
    /// handle time, not parse time. Clears the mailbox flag.
    static func fromWidgetStartRequest() -> IncomingAction? {
        guard let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
              defaults.object(forKey: WidgetShared.startWorkoutRequestKey) != nil
        else { return nil }
        defaults.removeObject(forKey: WidgetShared.startWorkoutRequestKey)
        return .startTodaysWorkout
    }

    /// Siri "Start <template>" shortcut. Clears the mailbox flag.
    static func fromTemplateStartRequest() -> IncomingAction? {
        guard let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
              let idString = defaults.string(forKey: WidgetShared.startTemplateWorkoutRequestKey),
              let uuid = UUID(uuidString: idString)
        else { return nil }
        defaults.removeObject(forKey: WidgetShared.startTemplateWorkoutRequestKey)
        return .startTemplate(uuid)
    }

    /// Widget "Complete set" tap. Clears the mailbox flag.
    static func fromCompleteSetRequest() -> IncomingAction? {
        guard let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
              defaults.object(forKey: WidgetShared.completeSetRequestKey) != nil
        else { return nil }
        defaults.removeObject(forKey: WidgetShared.completeSetRequestKey)
        return .completeActiveSet
    }
}
