//
//  OnboardingScreen.swift
//  vivobody
//
//  The one-time first-launch welcome, presented full-screen over
//  AppRoot until SettingsKey.onboardingCompleted flips true.
//
//  Deliberately NOT a wizard. workout-app-principles.md cuts
//  onboarding wizards, tutorial carousels, and motivational hero copy,
//  so this stays a single calm beat: brand, initial body weight, units,
//  and one way in. Body weight is worth capturing here because it makes
//  bodyweight-exercise load analytics accurate from the first workout.
//  Permissions (Health, notifications) remain contextual.
//
//  Tapping Start persists a real BodyWeightEntry before calling AppRoot,
//  which sets the @AppStorage completion flag and dismisses the cover.
//  The unit choice writes straight to SettingsKey.weightUnit; canonical
//  body-weight storage remains pounds at the scrubber boundary.
//

import VivoKit
import SwiftUI
import SwiftData

struct OnboardingScreen: View {
    /// Raised when the user taps Start. AppRoot owns the
    /// onboarding-completed flag and the cover's dismissal.
    let onStart: () -> Void

    @Environment(\.modelContext) private var context

    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var bodyWeightEntries: [BodyWeightEntry]

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    /// Canonical pounds. The scrubber converts at its UI boundary.
    @State private var bodyWeight: Double = 180
    /// Display-unit increment, local to this one-time setup surface.
    @State private var bodyWeightStep: Double = WeightUnit.lb.bodyWeightStep
    @State private var isSaving = false
    @State private var saveError: SaveErrorBox? = nil

    /// Shared identity for the single tinted glass "thumb" that morphs
    /// across the unit chips. Lives in one GlassEffectContainer so the
    /// container can slide the lensing between cells on selection.
    @Namespace private var glassNamespace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Deliberately top-anchored: the brand opens the screen and
            // leaves the centre to the one piece of personal setup.
            brand
                .padding(.top, Space.section)
                .settleIn(0)

            Spacer(minLength: Space.md)

            VStack(spacing: Space.section + Space.xl) {
                bodyWeightPicker

                unitPicker
            }
            .frame(maxWidth: 360)
            .settleIn(1)

            Spacer(minLength: Space.xl)

            startButton
                .settleIn(2)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .forgeBackground(intensity: 0.7)
        .onAppear(perform: hydrate)
        .saveErrorAlert($saveError)
    }

    // MARK: - Logo

    private var logo: some View {
        Image("LogoMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .foregroundStyle(Tint.primary)
            .accessibilityHidden(true)
    }

    // MARK: - Wordmark

    private var brand: some View {
        VStack(spacing: Space.md) {
            logo

            Text("vivobody")
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("vivobody")
    }

    // MARK: - Body weight

    private var bodyWeightPicker: some View {
        VStack(spacing: Space.sm) {
            Text("Your body weight")
                .panelLegend()

            WeightScrubber(
                canonicalWeight: $bodyWeight,
                purpose: .body,
                displayStep: bodyWeightStep,
                label: nil,
                pointsPerStep: 8,
                valueFontSize: 88,
                presentation: .bare,
                showsScrubHint: true,
                performsScrubNudge: true,
                centersValue: true
            )

            HStack(spacing: Space.md) {
                Text("Drag to adjust")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)

                Spacer(minLength: Space.md)

                bodyWeightStepButton
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The compact cycling increment control from Active Workout, tuned
    /// to scale precision instead of plate jumps.
    private var bodyWeightStepButton: some View {
        let options = weightUnit.bodyWeightStepOptions
        let label = WeightUnit.stepLabel(bodyWeightStep, unit: weightUnit.symbol)
        return Button {
            let index = options.firstIndex(of: bodyWeightStep) ?? 0
            let next = options[(index + 1) % options.count]
            Haptics.selection(
                pitch: Haptics.optionPitch(index: index, count: options.count),
                playsSound: true
            )
            bodyWeightStep = next
            snapBodyWeight(to: next, unit: weightUnit)
        } label: {
            Text(label)
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(4)
        .coloredGlassControl(cornerRadius: Radius.pill)
        .accessibilityLabel("Body weight increment")
        .accessibilityValue(label)
    }

    // MARK: - Unit picker

    private var unitPicker: some View {
        VStack(spacing: Space.lg) {
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
            let selectUnit = {
                weightUnitRaw = unit.rawValue
                bodyWeightStep = unit.bodyWeightStep
                snapBodyWeight(to: unit.bodyWeightStep, unit: unit)
            }
            // Drive the assignment through an animation transaction so
            // the shared-ID glass thumb morphs to the new cell instead
            // of snapping. Reduce Motion takes the instant path.
            if reduceMotion {
                selectUnit()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    selectUnit()
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
            .frame(maxWidth: .infinity, minHeight: Space.rowMin)
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
            saveAndStart()
        }
        .disabled(isSaving)
        .opacity(isSaving ? Opacity.medium : 1)
        .accessibilityHint("Finishes setup and opens the app")
    }

    // MARK: - Setup state

    private func hydrate() {
        if let latest = bodyWeightEntries.latest {
            bodyWeight = latest.weight
        }
        bodyWeightStep = weightUnit.bodyWeightStep
        snapBodyWeight(to: bodyWeightStep, unit: weightUnit)
    }

    private func snapBodyWeight(to step: Double, unit: WeightUnit) {
        let displayed = WeightFormatter.toDisplay(bodyWeight, unit: unit)
        let snapped = (displayed / step).rounded() * step
        bodyWeight = WeightFormatter.toCanonical(snapped, unit: unit)
    }

    private func saveAndStart() {
        guard !isSaving, bodyWeight.isFinite, bodyWeight > 0 else { return }
        isSaving = true
        Haptics.soft()

        let now = Date()
        if let existing = bodyWeightEntries.entry(on: now) {
            existing.date = now
            existing.weight = bodyWeight
        } else {
            context.insert(BodyWeightEntry(date: now, weight: bodyWeight))
        }

        do {
            try context.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: context)
            onStart()
        } catch {
            saveError = SaveErrorBox(error)
            isSaving = false
        }
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
        .modelContainer(for: BodyWeightEntry.self, inMemory: true)
}
