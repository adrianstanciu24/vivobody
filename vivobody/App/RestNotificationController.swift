//
//  RestNotificationController.swift
//  vivobody
//
//  Local "rest over" notification for the one moment the in-app rest
//  timer can't cover: the phone is locked or the app is backgrounded
//  when the countdown hits zero. Scheduled from AppRoot when the
//  scene leaves .active during a rest, cancelled the moment the scene
//  returns — so in the foreground the BreathingTimer remains the only
//  voice, and the notification never double-fires behind it.
//
//  The chime is sfx-rest-done.caf (Scripts/generate_sounds.py), the
//  same synth voice as the in-app sounds, so the identity carries to
//  the lock screen instead of falling back to the stock tri-tone.
//
//  Authorization is requested once, when the user starts their first
//  workout — the moment "tell me when rest is over" makes obvious
//  sense. If they decline, scheduling silently no-ops.
//

import UserNotifications

@MainActor
enum RestNotificationController {
    private static let requestID = "rest-timer-done"

    /// Prompt for notification permission (first call only; the
    /// system remembers the answer and later calls are no-ops).
    static func requestAuthorizationIfNeeded() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Schedule the rest-over chime at the session's rest deadline.
    /// No-ops unless a rest is actually running with time remaining.
    static func scheduleIfResting(for session: WorkoutSession?) {
        cancelPending()
        guard
            let session, session.isResting,
            let endsAt = session.restEndsAt
        else { return }

        let interval = endsAt.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName("sfx-rest-done.caf")
        )

        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: interval, repeats: false
            )
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Drop any scheduled chime and clear a delivered one from the
    /// notification center — once the user is back in the app, the
    /// banner is stale noise.
    static func cancelPending() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.removeDeliveredNotifications(withIdentifiers: [requestID])
    }
}
