//
//  OnboardingScreen.swift
//  vivobody
//
//  The one-time first-launch welcome, presented full-screen over
//  AppRoot until SettingsKey.onboardingCompleted flips true.
//
//  Deliberately NOT a wizard. workout-app-principles.md cuts
//  onboarding wizards, tutorial carousels, and "crush your goals"
//  hero copy outright, so this is a single calm beat: the wordmark,
//  one honest line, and the only setting that's genuinely painful to
//  get wrong later — pounds vs kilograms (every weight in the app is
//  displayed through it). Permissions (Health, notifications) stay
//  out of here and are requested in context the first time they
//  matter.
//
//  The screen owns no completion state itself; tapping Start calls
//  back to AppRoot, which sets the @AppStorage flag and dismisses
//  the cover. The unit choice writes straight to the same
//  SettingsKey.weightUnit that Settings reads, so it's already in
//  effect by the time the app appears.
//

import SwiftUI

struct OnboardingScreen: View {
    /// Raised when the user taps Start. AppRoot owns the
    /// onboarding-completed flag and the cover's dismissal.
    let onStart: () -> Void

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    /// Shared identity for the single tinted glass "thumb" that morphs
    /// across the unit chips. Lives in one GlassEffectContainer so the
    /// container can slide the lensing between cells on selection.
    @Namespace private var glassNamespace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Top half: the brand mark leads, wordmark + motto beneath.
            VStack(spacing: Space.xl) {
                Spacer(minLength: Space.section)
                logo
                wordmark
                Spacer(minLength: Space.section)
            }
            .frame(maxHeight: .infinity)
            .settleIn(0)

            // Bottom half: the one real choice, then the way in.
            VStack(spacing: Space.section) {
                unitPicker
                    .settleIn(1)
                startButton
                    .settleIn(2)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .forgeBackground(intensity: 0.7)
    }

    // MARK: - Logo

    private var logo: some View {
        Image("LogoMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 104, height: 104)
            .foregroundStyle(Tint.primary)
            .accessibilityHidden(true)
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        VStack(spacing: Space.sm) {
            Text("vivobody")
                .font(Typography.display)
                .foregroundStyle(Ink.primary)

            Text("Track your lifts. Nothing else.")
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("vivobody. Track your lifts. Nothing else.")
    }

    // MARK: - Unit picker

    private var unitPicker: some View {
        VStack(spacing: Space.sm) {
            Text("Which units do you lift in?")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(WeightUnit.allCases) { unit in
                        unitChip(unit)
                    }
                }
            }
            .frame(maxWidth: 260)
        }
    }

    private func unitChip(_ unit: WeightUnit) -> some View {
        let isSelected = unit == weightUnit
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        return Button {
            Haptics.selection()
            // Drive the assignment through an animation transaction so
            // the shared-ID glass thumb morphs to the new cell instead
            // of snapping. Reduce Motion takes the instant path.
            if reduceMotion {
                weightUnitRaw = unit.rawValue
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    weightUnitRaw = unit.rawValue
                }
            }
        } label: {
            HStack(spacing: Space.xs) {
                Text(unit.symbol)
                    .font(Typography.metricInline)
                Text(unit.displayName)
                    .font(Typography.micro)
                    .opacity(Opacity.emphasis)
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: Space.tapMin)
            .modifier(UnitChipSurface(isSelected: isSelected, shape: shape, namespace: glassNamespace))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unit.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Start

    private var startButton: some View {
        // No extra softElevation: PrimaryButtonStyle already carries
        // its own accent-glow + black shadows, and this static screen
        // has no scrolling content the CTA needs to lift off of.
        PrimaryActionButton(
            title: "Start",
            icon: "arrow.right",
            inputLabels: ["Start", "Begin", "Get Started"]
        ) {
            onStart()
        }
        .accessibilityHint("Finishes setup and opens the app")
    }
}

/// The per-chip surface. The selected chip wears the tinted Liquid
/// Glass behind its own label (so the label always renders on top and
/// stays readable), and carries the single shared `glassEffectID` —
/// the GlassEffectContainer morphs that one tinted blob across the gap
/// to the newly-selected chip. Unselected chips get a plain resting
/// content fill, no glass, so only the selection floats.
private struct UnitChipSurface: ViewModifier {
    let isSelected: Bool
    let shape: RoundedRectangle
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if isSelected {
            content
                .glassTinted(Tint.inProgress, interactive: true, in: shape)
                .glassEffectID("unitSelection", in: namespace)
        } else {
            content.background { shape.fill(Surface.cardTint) }
        }
    }
}

#Preview {
    OnboardingScreen(onStart: {})
        .preferredColorScheme(.dark)
}
