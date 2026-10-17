//
//  SetCompleteButton.swift
//  vivobody
//
//  The signature interaction: one big tap to complete a set.
//  Owns no business state — emits a toggle event, animates from `isComplete`.
//
//  A native Button with a custom press style, so scroll views cancel a
//  touch that turns into a swipe and VoiceOver, Voice Control, and
//  Full Keyboard Access get standard button behavior.
//
//  Composition of effects on idle → complete:
//    1. The shared set-completion recording over a crescendo — or,
//       on the exercise's last set, the same recording over a swell.
//    2. The dim volt tint floods with the full completion accent.
//    3. Numbers spring-overshoot (1.0 → 1.06 → 1.0).
//    4. A checkmark draws on only after completion.
//    5. A single radial ring expands from the button's center and fades.
//
//  Complete → idle (undo): Haptics.soft() and the same path in reverse.
//
//  The surface is Liquid Glass (.glassEffect) with the accent as its
//  tint — not an opaque fill. The system material owns the specular
//  highlights, rim lighting, and accessibility fallbacks (Reduce
//  Transparency / Increase Contrast), so no hand-drawn sheens,
//  darkening overlays, or stroke gradients are needed.
//

import SwiftUI
import VivoKit

enum SetIntensity {
    case standard
    case peak
}

struct SetCompleteButton: View {
    let reps: Int
    let weight: Double
    var loadMode: ExerciseLoadMode = .external
    let isComplete: Bool
    var intensity: SetIntensity = .standard
    /// When set, the button renders this verb (e.g. "Complete set")
    /// instead of repeating the reps × weight numbers. The numbers
    /// already live large above the button in the instrument layout,
    /// so echoing them here would be the duplication the redesign
    /// deletes. Icons are reserved for navigation — the action is a
    /// word.
    var title: String? = nil
    /// Overrides the spoken VoiceOver label for duration-tracked work.
    /// Rep work falls back to `loadMode`'s semantic wording so bodyweight,
    /// added load, assistance, and resistance never collapse to pounds.
    var accessibilityLabelOverride: String? = nil
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    @State private var numberScale: CGFloat = 1
    @State private var rippleId: Int = 0

    /// The flood-fill colour the moment the set is completed. Same
    /// accent as the live state — completion reads through the solid
    /// fill, the checkmark draw-on, and the haptic, not a new hue.
    private let accent = Tint.complete
    /// The live, "you're about to do this" colour worn by the idle
    /// button's surface and ripple.
    private let liveAccent = Tint.inProgress

    var body: some View {
        Button(action: fire) {
            ZStack {
                background
                ripple
                content
            }
            .frame(maxWidth: .infinity)
            // A verb-only action stays generous without outweighing the working
            // values. Numeric rows keep their taller footprint; enlarged action
            // text can grow in the accessibility layout's scrolling viewport.
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize || title == nil ? 96 : 64,
                idealHeight: dynamicTypeSize.isAccessibilitySize ? nil : (title == nil ? 96 : 72),
                maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : (title == nil ? 96 : 72)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(SetCompletePressStyle(reduceMotion: reduceMotion))
        // The Button already merges its label into one accessibility
        // element; `.accessibilityElement(children: .ignore)` here would
        // wrap it in a new element and drop the button trait and action.
        .accessibilityLabel(
            accessibilityLabelOverride
                ?? loadMode.completionAccessibilityLabel(
                    reps: reps,
                    loggedWeight: weight,
                    unit: unit
                )
        )
        .accessibilityValue(isComplete ? "completed" : "not completed")
        .accessibilityInputLabels(inputLabelValues)
        .accessibilityHint(isComplete ? "Double tap to undo." : "Double tap to complete the set.")
    }

    // MARK: - Layers

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        // Idle wears an opaque-enough volt wash under NEUTRAL glass so
        // the black action verb clears contrast without depending on
        // whatever content the material refracts. Completion adds the
        // fully tinted glass and checkmark in the same hue.
        return shape
            .fill(reduceTransparency
                ? (isComplete ? accent : liveAccent)
                : (isComplete ? accent.opacity(0.85) : liveAccent.opacity(0.85)))
            .glassTinted(isComplete ? accent : nil, interactive: true, in: shape)
            // The full accent bloom belongs to the completed state;
            // idle gets a quieter ember.
            .shadow(
                color: isComplete ? accent.opacity(0.50) : liveAccent.opacity(0.12),
                radius: isComplete ? 24 : 8,
                y: isComplete ? 9 : 4
            )
            .shadow(color: .black.opacity(isComplete ? 0.25 : 0.12), radius: 8, y: 4)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78), value: isComplete)
    }

    private var ripple: some View {
        Ripple(triggerId: rippleId, color: .white, reduceMotion: reduceMotion)
            // Fill the button so the clip below bounds the expanding ring
            // to the card rather than to the ring's own 60pt frame.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let title {
            ZStack(alignment: .trailing) {
                Text(title)
                    .font(Typography.title)
                    .tracking(0.4)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.55 : 0.7)
                    .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Tint.onAccent)
                    .padding(.horizontal, Space.tapMin)
                    .frame(maxWidth: .infinity)
                statusIndicator
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: isComplete)
        } else {
            HStack(alignment: .center, spacing: 0) {
                numberBlock(value: "\(reps)", unit: "reps")
                multiplier
                numberBlock(value: formattedWeight, unit: unit.symbol)
                Spacer(minLength: 8)
                statusIndicator
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .foregroundStyle(isComplete ? Tint.onAccent : Ink.primary)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: isComplete)
        }
    }

    private func numberBlock(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.metricLg)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .scaleEffect(reduceMotion ? 1.0 : numberScale)
            Text(unit)
                .font(Typography.metricUnit)
                .opacity(isComplete ? 0.65 : 0.55)
        }
    }

    private var multiplier: some View {
        Text("×")
            .font(Typography.statValue)
            .opacity(0.35)
            .padding(.horizontal, Space.lg)
            .offset(y: -8)
    }

    private var statusIndicator: some View {
        ZStack {
            if isComplete {
                Circle()
                    .fill(Tint.onAccent.opacity(0.12))
                    .frame(width: 44, height: 44)

                if reduceMotion {
                    checkmark
                        .transition(.opacity)
                } else {
                    checkmark
                        .transition(.symbolEffect(.drawOn))
                }
            }
        }
        // Reserve the completion lamp's footprint so its arrival never
        // shifts the verb, while leaving the idle action icon-free.
        .frame(width: 44, height: 44)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.62), value: isComplete)
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Tint.onAccent)
    }

    // MARK: - Action

    private func fire() {
        if isComplete {
            Haptics.soft()
        } else {
            // `.peak` is the exercise's last set, where the button
            // reads FINISH EXERCISE. Both actions share one completion
            // voice; the heavier haptic makes the final set land bigger.
            switch intensity {
            case .standard: Haptics.crescendo(sound: .setCompletion)
            case .peak: Haptics.swell(sound: .setCompletion)
            }
        }
        rippleId &+= 1

        if reduceMotion {
            numberScale = 1
        } else {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                numberScale = 1.06
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.08)) {
                numberScale = 1
            }
        }
        onToggle()
    }

    private var formattedWeight: String {
        WeightFormatter.string(weight, unit: unit, includeUnit: false)
    }

    /// Voice Control synonyms derived from the button's current
    /// title (or accessibility override). When a verb title is set
    /// ("Complete set", "Finish exercise"), it leads so a user can
    /// say "tap complete" or "tap finish." Generic synonyms ("Done",
    /// "Complete", "Finish") follow so natural phrasing always works.
    private var inputLabelValues: [Text] {
        if let override = accessibilityLabelOverride {
            return [Text(override), Text("Complete"), Text("Done"), Text("Finish")]
        }
        if let title {
            return [Text(title), Text("Complete"), Text("Done"), Text("Finish")]
        }
        return [Text("Complete set"), Text("Complete"), Text("Done"), Text("Finish")]
    }
}

// MARK: - Press style

private struct SetCompletePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(pressAnimation(isPressed: configuration.isPressed), value: configuration.isPressed)
    }

    private func pressAnimation(isPressed: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        return isPressed
            ? .spring(response: 0.22, dampingFraction: 0.7)
            : .spring(response: 0.32, dampingFraction: 0.55)
    }
}

// MARK: - Ripple

private struct Ripple: View {
    let triggerId: Int
    let color: Color
    var reduceMotion: Bool = false

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(reduceMotion ? 1.0 : scale, anchor: .center)
            .opacity(opacity)
            .onChange(of: triggerId) { _, _ in
                if reduceMotion {
                    return
                }
                scale = 0.2
                opacity = 0.7
                withAnimation(.easeOut(duration: 0.55)) {
                    scale = 4.5
                    opacity = 0
                }
            }
    }
}
