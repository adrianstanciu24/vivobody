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
//  Authorization is requested only after an explicit user action in
//  the contextual first-rest primer or Settings. Fresh installs never
//  receive a system permission prompt merely for starting a workout.
//

import UserNotifications

nonisolated enum RestNotificationAuthorization: Equatable {
    case notDetermined
    case denied
    case authorized
}

@MainActor
enum RestNotificationController {
    private static let requestID = "rest-timer-done"
    private static var schedulingTask: Task<Void, Never>?

    static func authorizationStatus() async -> RestNotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    /// Request permission only from a user-initiated consent action.
    /// The caller owns the explanatory UI shown before this method.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
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

        schedulingTask = Task { @MainActor in
            let status = await authorizationStatus()
            guard !Task.isCancelled else { return }
            let defaults = UserDefaults.standard
            let hasStoredPreference = defaults.object(
                forKey: SettingsKey.restNotificationsEnabled
            ) != nil
            let isEnabled: Bool
            if hasStoredPreference {
                isEnabled = defaults.bool(forKey: SettingsKey.restNotificationsEnabled)
            } else {
                // Preserve delivery for existing users who accepted the old
                // automatic prompt before this explicit-consent preference
                // existed. Fresh installs remain disabled.
                isEnabled = status == .authorized
                if isEnabled {
                    defaults.set(true, forKey: SettingsKey.restNotificationsEnabled)
                }
            }
            guard isEnabled, status == .authorized else { return }
            guard !Task.isCancelled else { return }

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
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Drop any scheduled chime and clear a delivered one from the
    /// notification center — once the user is back in the app, the
    /// banner is stale noise.
    static func cancelPending() {
        schedulingTask?.cancel()
        schedulingTask = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.removeDeliveredNotifications(withIdentifiers: [requestID])
    }
}
