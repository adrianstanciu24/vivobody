//
//  ActiveWorkoutMiniBar.swift
//  vivobody
//
//  The compact form of an in-progress workout — a horizontal pill
//  designed to sit in iOS 26's `.tabViewBottomAccessory` slot above
//  the floating tab bar (the same architectural slot Apple uses for
//  Music's MiniPlayer).
//
//  Why it exists:
//    A workout has long rest periods (60–180s) during which the user
//    is idle. The MiniBar gives them an ambient reminder that a
//    workout is in progress while letting them navigate freely
//    (History to compare last week's lifts, Library to check form).
//    Tap the bar to expand back to the full ActiveWorkoutScreen.
//
//  States it renders:
//    • RESTING    — live countdown like "REST 0:47" ticking down
//                   once per second via TimelineView. Pulsing dot in
//                   muscle-group color. Haptic + state-flip when the
//                   countdown reaches zero.
//    • READY      — between sets but not resting. Pulsing dot in
//                   muscle-group color. White-dim "READY" badge.
//    • COMPLETE   — every set logged. Static green dot, no pulse.
//                   "TAP TO FINISH" badge. The two-line label switches
//                   to a workout-level title ("Workout") + subtitle
//                   ("ALL SETS LOGGED") so vertical rhythm stays
//                   aligned with the in-progress layout.
//
//  Component contract:
//    Takes a session binding and a single onExpand callback. Knows
//    nothing about TabView, NavigationStack, fullScreenCover, or
//    AppState. The shell wires it.
//

import VivoKit
import SwiftUI
import SwiftData

struct ActiveWorkoutMiniBar: View {
    @Bindable var session: WorkoutSession
    var onExpand: () -> Void

    private let completedGreen = Tint.success
    private let restTint       = Tint.primary
    private let readyTint      = Ink.secondary

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            barContent(now: context.date)
        }
    }

    @ViewBuilder
    private func barContent(now: Date) -> some View {
        Button(action: {
            Haptics.soft()
            onExpand()
        }) {
            switch placement {
            case .expanded:
                expandedLayout(now: now)
            default:
                compactLayout(now: now)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("activeWorkoutMiniBar")
        .accessibilityHint("Tap to expand workout")
        .accessibilityInputLabels([Text("Workout"), Text("Active workout"), Text("Resume")])
        .task(id: restJustExpired(now: now)) {
            if restJustExpired(now: now) {
                Haptics.swell()
                session.skipRest()
                try? modelContext.save()
                WorkoutLiveActivityController.update(for: session)
                WidgetSnapshotWriter.writeActiveWorkout(in: modelContext)
            }
        }
    }

    private func compactLayout(now: Date) -> some View {
        barRow(now: now)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
    }

    /// The accessory slot is a single-row height regardless of
    /// placement — `.expanded` only grants more horizontal room, not
    /// vertical. So both placements render one horizontal row;
    /// stacking the badge on a second line overflows and clips it.
    private func expandedLayout(now: Date) -> some View {
        barRow(now: now)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
    }

    private func barRow(now: Date) -> some View {
        HStack(spacing: 12) {
            PulseDot(color: dotColor, isPulsing: shouldPulse)
            labels
            Spacer(minLength: 8)
            statusBadge(now: now)
            Image(systemName: "chevron.up")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
    }

    // MARK: - Labels

    /// Title plus an optional subtitle. The subtitle line is only
    /// emitted when it has content — an empty second line would
    /// reserve vertical space and push the title above the row's
    /// centerline (the dot and badge stay centered).
    private var labels: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(titleText)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)

            if !subtitleText.isEmpty {
                Text(subtitleText)
                    .panelLegendType()
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }
        }
    }

    /// Right-side state badge — switches between Rest countdown, Ready,
    /// or Tap to finish. Tinted to match its meaning.
    @ViewBuilder
    private func statusBadge(now: Date) -> some View {
        if session.isAllComplete {
            badgeText("Tap to finish", tint: completedGreen)
        } else if session.isResting {
            let remaining = max(0, Int(session.restRemaining.rounded(.up)))
            badgeText("Rest \(formatTime(remaining))", tint: restTint)
        } else {
            badgeText("Ready", tint: readyTint)
        }
    }

    private func badgeText(_ text: String, tint: Color) -> some View {
        Text(text)
            .panelLegendType()
            .foregroundStyle(tint)
            .monospacedDigit()
    }

    // MARK: - Derived

    /// The exercise to display. When `activeExerciseIndex` has walked
    /// past the last exercise (the summary card is in focus), fall back
    /// to the final exercise so the dot still has its muscle-group
    /// color rather than a generic white fallback.
    private var displayExercise: Exercise? {
        let exercises = session.orderedExercises
        if session.activeExerciseIndex >= 0,
           session.activeExerciseIndex < exercises.count {
            return exercises[session.activeExerciseIndex]
        }
        return exercises.last
    }

    /// Green when every set is logged; otherwise the active exercise's
    /// muscle-group accent.
    private var dotColor: Color {
        if session.isAllComplete { return completedGreen }
        return displayExercise?.group.accent ?? Ink.primary
    }

    /// Pulse while a workout is genuinely *in flight* (active session,
    /// not yet complete). Static when complete so the green dot reads
    /// as "settled" rather than "still happening."
    private var shouldPulse: Bool {
        !session.isAllComplete
    }

    private var titleText: String {
        if session.isAllComplete { return "Workout" }
        return displayExercise?.name ?? "Workout"
    }

    private var subtitleText: String {
        if session.isAllComplete { return "All sets logged" }
        guard let exercise = displayExercise else { return "" }
        if let nextIndex = session.activeSetIndex(for: exercise) {
            return "Set \(nextIndex + 1) of \(exercise.orderedSets.count)"
        }
        return "All sets done"
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(titleText)
        parts.append(subtitleText)
        if session.isResting {
            parts.append("Resting \(Int(session.restRemaining)) seconds")
        } else if session.isAllComplete {
            parts.append("Workout complete")
        } else {
            parts.append("Ready for next set")
        }
        return parts.joined(separator: ". ")
    }

    /// True only at the exact tick when rest has elapsed and we
    /// haven't yet flipped session state. Drives the haptic + state
    /// transition.
    private func restJustExpired(now: Date) -> Bool {
        guard session.isResting else { return false }
        if let deadline = session.restEndsAt {
            return now >= deadline
        }
        guard let started = session.restStartedAt else { return false }
        return now.timeIntervalSince(started) >= session.restDuration
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Pulse dot

/// Self-contained indicator that breathes like an armed LED. When
/// `isPulsing` is true, glow and brightness ease back and forth at
/// standby rate; when false, settles to a steady dot. State lives
/// inside so a parent can flip the flag without thinking about
/// animation lifecycles.
private struct PulseDot: View {
    let color: Color
    let isPulsing: Bool

    @State private var phase: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(
                Circle().stroke(Ink.quaternary, lineWidth: 0.5)
            )
            .brightness(phase ? 0.18 : 0)
            .shadow(color: color.opacity(phase ? 0.55 : 0.12), radius: phase ? 5 : 2)
            .animation(animation, value: phase)
            .onAppear { phase = isPulsing }
            .onChange(of: isPulsing) { _, newValue in
                phase = newValue
            }
    }

    private var animation: Animation {
        if isPulsing {
            return .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
        } else {
            return .easeOut(duration: 0.3)
        }
    }
}

#Preview("Ready") {
    ActiveWorkoutMiniBar(session: WorkoutSession.sample, onExpand: {})
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Resting") {
    let session = WorkoutSession.sample
    session.isResting = true
    session.restStartedAt = Date().addingTimeInterval(-30)
    return ActiveWorkoutMiniBar(session: session, onExpand: {})
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Complete") {
    ActiveWorkoutMiniBar(session: WorkoutSession.sampleCompleted, onExpand: {})
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
