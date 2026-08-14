//
//  AppDiagnostics.swift
//  vivobody
//
//  Privacy-safe unified logging for load-bearing app boundaries. Events use
//  stable machine-readable kinds and outcomes so Baguette scenarios can assert
//  behavior without exposing user-owned workout or HealthKit data.
//

import Foundation
import OSLog

nonisolated enum AppDiagnostics {
    private static let subsystem = "astanciu.vivobody.app"

    private static let storage = Logger(subsystem: subsystem, category: "storage")
    private static let incomingAction = Logger(subsystem: subsystem, category: "incoming-action")
    private static let session = Logger(subsystem: subsystem, category: "session")
    private static let snapshot = Logger(subsystem: subsystem, category: "snapshot")
    private static let healthKit = Logger(subsystem: subsystem, category: "healthkit")

    static func storageFallbackAttempt(error: any Error) {
        let error = error as NSError
        storage.error(
            "event=storage.open outcome=fallback_attempt error_domain=\(error.domain, privacy: .private) error_code=\(error.code, privacy: .public)"
        )
    }

    static func storageFallbackSucceeded() {
        storage.fault("event=storage.open outcome=fallback_memory")
    }

    static func storageUnavailable(error: any Error) {
        let error = error as NSError
        storage.fault(
            "event=storage.open outcome=unavailable error_domain=\(error.domain, privacy: .private) error_code=\(error.code, privacy: .public)"
        )
    }

    static func incomingActionReceived(kind: String) {
        incomingAction.notice(
            "event=incoming_action.received kind=\(kind, privacy: .public)"
        )
    }

    static func sessionTransition(kind: String, outcome: String) {
        session.notice(
            "event=session.transition kind=\(kind, privacy: .public) outcome=\(outcome, privacy: .public)"
        )
    }

    static func sessionTransitionFailed(kind: String, error: any Error) {
        let error = error as NSError
        session.error(
            "event=session.transition kind=\(kind, privacy: .public) outcome=failure error_domain=\(error.domain, privacy: .private) error_code=\(error.code, privacy: .public)"
        )
    }

    static func snapshotWrite(kind: String, outcome: String) {
        if outcome == "success" {
            snapshot.notice(
                "event=snapshot.write kind=\(kind, privacy: .public) outcome=success"
            )
        } else {
            snapshot.error(
                "event=snapshot.write kind=\(kind, privacy: .public) outcome=\(outcome, privacy: .public)"
            )
        }
    }

    static func healthKitOutcome(event: String, outcome: String) {
        healthKit.notice(
            "event=healthkit.\(event, privacy: .public) outcome=\(outcome, privacy: .public)"
        )
    }

    static func healthKitFailed(event: String, error: any Error) {
        let error = error as NSError
        healthKit.error(
            "event=healthkit.\(event, privacy: .public) outcome=failure error_domain=\(error.domain, privacy: .private) error_code=\(error.code, privacy: .public)"
        )
    }
}
