//
//  UserActivity.swift
//  vivobody
//
//  NSUserActivity plumbing for the active workout. Publishing a
//  "continue workout" activity lets iOS do three things for us
//  without any custom sync or push layer:
//
//    1. Restore the app to the active workout after a background
//       kill. AppState.restoreActiveWorkoutIfNeeded already handles
//       cold-launch restore from SwiftData; this is the system-level
//       complement that also covers warm relaunch and gives iOS a
//       resumable activity to surface proactively.
//    2. Handoff. A workout started on this iPhone shows a "continue
//       in vivobody" banner on the user's other iCloud devices
//       (iPad, and eventually watch once the watchOS track lands).
//       Tapping it relaunches us and hands the activity back via
//       .onContinueUserActivity.
//    3. Siri Suggestions. With isEligibleForPrediction on, iOS
//       learns "user starts a workout around this time / place" and
//       surfaces a lock-screen / Spotlight shortcut, removing the
//       unlock -> find app -> start chain that the principles doc
//       calls out as failure.
//
//  The activity carries only the session's stable UUID in userInfo.
//  The full session state lives in SwiftData; the activity is just a
//  lightweight pointer the system can hand back to us on continue.
//  On continue we fetch that session by id and hand it to AppState,
//  mirroring restoreActiveWorkoutIfNeeded but targeted at a specific
//  session instead of "the newest unarchived draft".
//
//  Watch handoff is deliberately out of scope for this pass; it
//  belongs to the watchOS track, which already assumes this plumbing
//  in watchos-architecture-research.md.
//

import Foundation

enum ContinueWorkoutActivity {
    /// Reverse-DNS activity type. Must match between publish
    /// (`.userActivity(_:isActive:_:)` in AppRoot) and continue
    /// (`.onContinueUserActivity(_:)` in AppRoot), and must be
    /// declared in Info.plist under NSUserActivityTypes.
    static let activityType = "astanciu.vivobody.app.continueWorkout"

    /// The single userInfo key we write/read: the session's stable
    /// UUID as a string. Kept as a plain plist type so the activity
    /// round-trips through the system without Codable ceremony, and
    /// so a future watch target can read the same key without
    /// importing the app's model layer.
    static let sessionIDKey = "vivobody.sessionID"

    /// Build the userInfo dict for a session. Returns nil when given
    /// a nil session; callers gate on a non-nil session before
    /// publishing, but the guard keeps the call site unconditional.
    static func userInfo(for session: WorkoutSession?) -> [AnyHashable: Any]? {
        guard let session else { return nil }
        return [sessionIDKey: session.id.uuidString]
    }

    /// Extract the session UUID from a continued activity's userInfo.
    /// Returns nil if the key is missing or the value isn't a valid
    /// UUID string, so the continue handler can no-op gracefully on a
    /// stale or malformed activity.
    static func sessionID(from activity: NSUserActivity) -> UUID? {
        guard let raw = activity.userInfo?[sessionIDKey] as? String else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    /// A short, human-readable title for the activity: what shows on
    /// the Handoff banner and in Siri Suggestions. Reflects the
    /// current exercise + set so the affordance reads as live, e.g.
    /// "Bench Press · set 3 of 5". Falls back to a generic label when
    /// the session has no exercises yet (blank-canvas start) or the
    /// active index is momentarily out of range.
    static func title(for session: WorkoutSession) -> String {
        let exercises = session.orderedExercises
        guard exercises.indices.contains(session.activeExerciseIndex) else {
            return "Workout in progress"
        }
        let exercise = exercises[session.activeExerciseIndex]
        let sets = exercise.orderedSets
        let total = sets.count
        guard total > 0 else { return exercise.name }
        if let activeIndex = session.activeSetIndex(for: exercise) {
            let setNumber = min(activeIndex + 1, total)
            return "\(exercise.name) · set \(setNumber) of \(total)"
        }
        // All sets on this exercise are done; the pager is about to
        // advance to the next one, so report the last set.
        return "\(exercise.name) · set \(total) of \(total)"
    }
}
