//
//  StepSelector.swift
//  vivobody
//
//  Pill segmented control for choosing one value from a small fixed set.
//  Used for: weight step (1 / 2.5 / 5), units (lb / kg), and similar.
//
//  A single capsule slides between options via matchedGeometryEffect —
//  fade-swap looks software, sliding looks mechanical, which is honest:
//  the user is choosing a position, not a category.
//

import SwiftUI

struct StepSelector<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    @Namespace private var indicatorNS

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    if option != selection {
                        Haptics.selection()
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(Typography.metricUnit)
                        .monospacedDigit()
                        .foregroundStyle(option == selection ? Surface.background : Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .contentShape(Capsule())
                        .background {
                            if option == selection {
                                Capsule()
                                    .fill(Ink.primary)
                                    .matchedGeometryEffect(id: "indicator", in: indicatorNS)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Surface.cardTint))
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selection)
    }
}

#Preview("Step Selector") {
    @Previewable @State var step: Double = 5
    return VStack(spacing: Space.xxl) {
        StepSelector(
            selection: $step,
            options: [1.0, 2.5, 5.0]
        ) { value in
            value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value)) lb"
                : String(format: "%.1f lb", value)
        }
        Text("Current: \(step.formatted()) lb")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))
    }
    .padding(Space.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
