//
//  RIRSelector.swift
//  vivobody
//
//  Picks reps-in-reserve for a set — how many more reps the lifter
//  felt they had left at the end. A 0…5 pill (0 = to failure, 5 =
//  many left in the tank); 0…5 is the usable RIR range, beyond which
//  the self-estimate is noise. Reuses the app's standard StepSelector
//  pill so it reads like every other "pick one of a small set" control
//  (weight step, units). A live caption translates the number into
//  plain language so the scale never needs explaining.
//

import SwiftUI

struct RIRSelector: View {
    @Binding var value: Int

    private let options = Array(0...5)

    /// Chip / echo label for a stored RIR value. The top of the scale
    /// is open-ended ("5+") because RIR above 5 is indistinguishable
    /// from failure-distance standpoint — 5 and 10 reps in the tank
    /// both just mean "well short of failure." Single source of truth
    /// so the pill, caption, and "Last …" echo all read alike.
    static func displayLabel(_ value: Int) -> String {
        value >= 5 ? "5+" : "\(value)"
    }

    /// Feedback graded by the effort the number represents, not by
    /// which direction the finger moved. 5+ (easy) is the standard
    /// light selection blip; each step toward failure drops the tone,
    /// and 0 — to failure — lands as a deep, heavy thud instead of a
    /// blip. You hear how hard the set was.
    private static func effortFeedback(for rir: Int) {
        if rir == 0 {
            Haptics.thunk(pitch: -0.5)
        } else {
            Haptics.selection(pitch: Double(rir - 5) / 5)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("RIR")
                    .panelLegend()
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }

            StepSelector(
                selection: $value,
                options: options,
                label: { Self.displayLabel($0) },
                feedback: { Self.effortFeedback(for: $0) }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reps in reserve")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let next: Int
            switch direction {
            case .increment: next = min(5, value + 1)
            case .decrement: next = max(0, value - 1)
            @unknown default: return
            }
            if next != value {
                value = next
                Self.effortFeedback(for: next)
            }
        }
    }

    private var caption: String {
        switch value {
        case 0: return "to failure"
        case 5: return "5 or more left in the tank"
        default: return "\(value) left in the tank"
        }
    }

    private var accessibilityValue: String {
        switch value {
        case 0: return "0, to failure"
        case 5: return "5 or more reps in reserve"
        default: return "\(value) reps in reserve"
        }
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
