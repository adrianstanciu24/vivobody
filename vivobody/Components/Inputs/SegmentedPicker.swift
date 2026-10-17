//
//  SegmentedPicker.swift
//  vivobody
//
//  The app's one segmented control for choosing a value from a small fixed
//  set: weight step, units, appearance, Library scope, catalog fields, RIR.
//
//  Native `Picker(.segmented)` is about 32pt tall and cannot carry the
//  tinted thumb, so this keeps the Liquid Glass track, the electric-orange
//  thumb, and 44pt segments while every site shares one implementation.
//

import SwiftUI
import VivoKit

struct SegmentedPicker<Option: Hashable, Label: View>: View {
    @Binding var selection: Option
    let options: [Option]
    /// Spoken name for each segment. Scenarios and VoiceOver read this.
    let accessibilityLabel: (Option) -> String
    /// Replaces the default `Haptics.selection()` on pick. Pass `{ _ in }`
    /// when the binding's setter already plays feedback.
    var feedback: ((Option) -> Void)? = nil
    /// Repeats feedback when the selected option is tapped again.
    var feedbackOnReselection: Bool = false
    /// Stacks segments vertically at accessibility text sizes instead of
    /// shrinking labels. Leave off where the control lives in a fixed panel.
    var stacksAtAccessibilitySizes: Bool = false
    var minSegmentHeight: CGFloat = Space.tapMin
    @ViewBuilder let label: (Option, Bool) -> Label

    @Namespace private var thumbNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The selected thumb overdrives briefly and decays, so a pick reads as
    /// a light snapping over rather than a cross-fade.
    @State private var snapPulse = false

    private var isStacked: Bool {
        stacksAtAccessibilitySizes && dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        let layout = isStacked
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
        GlassEffectContainer(spacing: 4) {
            layout {
                ForEach(options, id: \.self) { option in
                    segment(option)
                }
            }
            .padding(4)
            .coloredGlassControl(cornerRadius: Radius.pill)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78), value: selection)
        .onChange(of: selection) { _, _ in
            guard !reduceMotion else { return }
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) { snapPulse = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.05)) { snapPulse = false }
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            guard !isSelected || feedbackOnReselection else { return }
            if let feedback {
                feedback(option)
            } else {
                Haptics.selection()
            }
            if !isSelected {
                selection = option
            }
        } label: {
            HStack(spacing: Space.xs) {
                if isSelected, differentiateWithoutColor {
                    Image(systemName: "checkmark")
                        .font(Typography.micro)
                        .accessibilityHidden(true)
                }
                label(option, isSelected)
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity, minHeight: minSegmentHeight)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Color.clear
                        .matchedGeometryEffect(id: "thumb", in: thumbNamespace)
                        .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
                        .brightness(snapPulse ? 0.22 : 0)
                        .shadow(color: Tint.inProgress.opacity(snapPulse ? 0.55 : 0), radius: 9)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(option))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension SegmentedPicker where Label == SegmentedPickerText {
    /// Text-only segments. `font` defaults to the compact metric face used
    /// by step and unit pickers.
    init(
        selection: Binding<Option>,
        options: [Option],
        font: Font = Typography.metricUnit,
        feedback: ((Option) -> Void)? = nil,
        feedbackOnReselection: Bool = false,
        stacksAtAccessibilitySizes: Bool = false,
        label: @escaping (Option) -> String
    ) {
        self.init(
            selection: selection,
            options: options,
            accessibilityLabel: label,
            feedback: feedback,
            feedbackOnReselection: feedbackOnReselection,
            stacksAtAccessibilitySizes: stacksAtAccessibilitySizes,
            label: { option, isSelected in
                SegmentedPickerText(text: label(option), font: font, isSelected: isSelected)
            }
        )
    }
}

struct SegmentedPickerText: View {
    let text: String
    let font: Font
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(isSelected ? .semibold : nil)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
