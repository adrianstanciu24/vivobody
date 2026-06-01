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

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 6) {
                Text("RIR")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }

            StepSelector(selection: $value, options: options) { Self.displayLabel($0) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reps in reserve")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(5, value + 1)
            case .decrement: value = max(0, value - 1)
            @unknown default: break
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
    return VStack(spacing: 24) {
        RIRSelector(value: $rir)
        Text("Current: \(rir) RIR")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
