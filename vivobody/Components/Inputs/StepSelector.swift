//
//  StepSelector.swift
//  vivobody
//
//  Pill segmented control for choosing one value from a small fixed set.
//  Used for: weight step (1 / 2.5 / 5), units (lb / kg), and similar.
//
//  The control is a compact Liquid Glass segmented bar: one neutral
//  glass track, with the selected segment riding on the app's tinted
//  glass thumb. This matches the Library segment control and keeps
//  small option pickers in the same iOS 26 control vocabulary.
//

import VivoKit
import SwiftUI

struct StepSelector<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    /// Optional replacement for the default Haptics.selection() fired
    /// when an option is picked. Lets semantically-loaded selectors
    /// (RIR: 0 = to failure) grade their feedback by the value chosen
    /// rather than emitting one uniform blip.
    var feedback: ((T) -> Void)? = nil

    @Namespace private var indicatorNS

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Light-snap: the instant a segment is picked its lamp overdrives
    /// (brightness + a brief glow bloom) and decays to rest — the
    /// selection is an LED snapping over, not a cross-fade.
    @State private var snapPulse: Bool = false

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
            .padding(4)
            .coloredGlassControl(cornerRadius: Radius.pill)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: selection)
        .onChange(of: selection) { _, _ in
            guard !reduceMotion else { return }
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) { snapPulse = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.05)) { snapPulse = false }
        }
    }

    private func optionButton(_ option: T) -> some View {
        let isSelected = option == selection
        return Button {
            guard option != selection else { return }
            if let feedback {
                feedback(option)
            } else {
                Haptics.selection()
            }
            selection = option
        } label: {
            Text(label(option))
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .contentShape(Capsule())
                .background {
                    if isSelected {
                        Color.clear
                            .matchedGeometryEffect(id: "indicator", in: indicatorNS)
                            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
                            .brightness(snapPulse ? 0.22 : 0)
                            .shadow(
                                color: Tint.inProgress.opacity(snapPulse ? 0.55 : 0),
                                radius: 9
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
