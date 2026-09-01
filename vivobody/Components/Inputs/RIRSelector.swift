//
//  RIRSelector.swift
//  vivobody
//
//  Picks reps-in-reserve for a set — how many more reps the lifter
//  felt they had left at the end. A 0…5 pill (0 = to failure, 5 =
//  many left in the tank); 0…5 is the usable RIR range, beyond which
//  the self-estimate is noise. Reuses the app's standard StepSelector
//  pill so it reads like every other "pick one of a small set" control
//  (weight step, units). A caption names the effort in plain language
//  ("left in the tank") while the pill owns the number, so the scale
//  never needs explaining and nothing reads twice.
//

import SwiftUI
import VivoKit

struct RIRSelector: View {
    @Binding var value: Int

    private let options = Array(0 ... 5)

    /// Chip / echo label for a stored RIR value. The top of the scale
    /// is open-ended ("5+") because RIR above 5 is indistinguishable
    /// from failure-distance standpoint — 5 and 10 reps in the tank
    /// both just mean "well short of failure." Single source of truth
    /// so the pill, caption, and "Last …" echo all read alike.
    static func displayLabel(_ value: Int) -> String {
        value >= 5 ? "5+" : "\(value)"
    }

    /// Every value uses the same recorded click. The haptic remains graded
    /// by effort, with 0, to failure, landing as a heavier impact.
    private static func effortFeedback(for rir: Int) {
        Haptics.rir(rir)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("RIR")
                    .panelLegend()
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }

            StepSelector(
                selection: $value,
                options: options,
                label: { Self.displayLabel($0) },
                feedback: { Self.effortFeedback(for: $0) },
                feedbackOnReselection: true
            )
        }
        // This control is already compact. Preserve its ideal vertical
        // footprint when a long exercise name makes the fixed workout
        // panel negotiate for space; the hero or completion action can
        // yield instead.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityRepresentation {
            Slider(value: accessibilitySliderBinding, in: 0 ... 5, step: 1) {
                Text("Reps in reserve")
            }
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Swipe up or down to change")
        }
    }

    /// The effort in words, without restating the number — the
    /// selected chip already says "2", the caption says what it means.
    private var caption: String {
        switch value {
        case 0: "to failure"
        case 5: "well short of failure"
        default: "left in the tank"
        }
    }

    private var accessibilityValue: String {
        switch value {
        case 0: "0, to failure"
        case 5: "5 or more reps in reserve"
        default: "\(value) reps in reserve"
        }
    }

    private var accessibilitySliderBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                guard newValue.isFinite else { return }
                let next = min(5, max(0, Int(newValue.rounded())))
                guard next != value else { return }
                value = next
                Self.effortFeedback(for: next)
            }
        )
    }
}

#Preview("RIR Selector") {
    @Previewable @State var rir = 2
    return VStack(spacing: Space.xxl) {
        RIRSelector(value: $rir)
        Text("Current: \(rir) RIR")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))
    }
    .padding(Space.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
