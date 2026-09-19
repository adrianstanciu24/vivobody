//
//  OnboardingScreen.swift
//  vivobody
//
//  The one-time first-launch welcome. AppRoot renders it as the window's
//  root until SettingsKey.onboardingCompleted flips true.
//
//  Deliberately NOT a wizard. workout-app-principles.md cuts
//  onboarding wizards, tutorial carousels, and motivational hero copy,
//  so this stays a single calm beat: brand, optional body weight, units,
//  and one way in. Body weight improves bodyweight-exercise load analytics,
//  but an untouched suggestion must never become a recorded measurement.
//  Permissions (Health, notifications) remain contextual.
//
//  The user explicitly opts into body-weight entry before the scrubber is
//  activated. Tapping Start persists it only in that state, then calls AppRoot,
//  which sets the @AppStorage completion flag and switches to the main app. The
//  unit choice writes straight to SettingsKey.weightUnit; canonical storage
//  remains pounds at the scrubber boundary.
//

import SwiftData
import SwiftUI
import VivoKit

struct OnboardingScreen: View {
    /// Raised when the user taps Start. AppRoot owns the
    /// onboarding-completed flag and transition to the main app.
    let onStart: () -> Void

    @Environment(\.modelContext) private var context

    @Query
    private var bodyWeightEntries: [BodyWeightEntry]

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart
        var latestBodyweight = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        latestBodyweight.fetchLimit = 1
        _bodyWeightEntries = Query(latestBodyweight)
    }

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    /// Canonical pounds. The scrubber converts at its UI boundary.
    @State private var bodyWeight: Double = 180
    @State private var includesBodyWeight = false
    /// Display-unit increment, local to this one-time setup surface.
    @State private var bodyWeightStep: Double = WeightUnit.lb.bodyWeightStep
    @State private var isSaving = false
    @State private var saveError: SaveErrorBox? = nil

    /// Shared identity for the single tinted glass "thumb" that morphs
    /// across the unit chips. Lives in one GlassEffectContainer so the
    /// container can slide the lensing between cells on selection.
    @Namespace private var glassNamespace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                accessibilityLayout
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollIndicators(.hidden)
            .screenBackground()
            .onAppear(perform: hydrate)
            .task(prepareFeedback)
            .saveErrorAlert($saveError)
        } else {
            standardLayout
                .screenBackground()
                .onAppear(perform: hydrate)
                .task(prepareFeedback)
                .saveErrorAlert($saveError)
        }
    }

    private var standardLayout: some View {
        VStack(spacing: 0) {
            // Deliberately top-anchored: the brand opens the screen and
            // leaves the centre to the one piece of personal setup.
            brand
                .padding(.top, Space.section)

            Spacer(minLength: Space.md)

            VStack(spacing: Space.section + Space.xl) {
                bodyWeightPicker
                unitPicker
                    .modifier(OnboardingStateVisibility(isVisible: includesBodyWeight))
            }
            .frame(maxWidth: 360)

            Spacer(minLength: Space.xl)

            onboardingActions
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Accessibility categories trade the fixed, spacer-driven stage
    /// for a single continuous scroll so every label and control can
    /// grow at its requested size without clipping the Start action.
    private var accessibilityLayout: some View {
        VStack(spacing: Space.section) {
            brand

            VStack(spacing: Space.section) {
                bodyWeightPicker
                unitPicker
                    .modifier(OnboardingStateVisibility(isVisible: includesBodyWeight))
            }
            .frame(maxWidth: 360)

            onboardingActions
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.section)
        .frame(maxWidth: .infinity)
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
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(Ink.primary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("vivobody")
    }

    // MARK: - Body weight

    private var bodyWeightPicker: some View {
        VStack(spacing: Space.md) {
            Text("Body weight · Optional")
                .panelLegend()

            ZStack {
                VStack(spacing: Space.md) {
                    WeightScrubber(
                        canonicalWeight: $bodyWeight,
                        purpose: .body,
                        displayStep: bodyWeightStep,
                        label: nil,
                        pointsPerStep: 8,
                        valueFontSize: 88,
                        presentation: .bare,
                        showsScrubHint: includesBodyWeight,
                        performsScrubNudge: includesBodyWeight,
                        keepsRailVisible: true,
                        centersValue: true
                    )

                    bodyWeightStepControl
                }
                .modifier(OnboardingStateVisibility(isVisible: includesBodyWeight))

                bodyWeightEmptyState
                    .modifier(OnboardingStateVisibility(isVisible: !includesBodyWeight))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var bodyWeightEmptyState: some View {
        VStack(spacing: Space.sm) {
            Text("Not set")
                .font(Typography.metricLg)
                .foregroundStyle(Ink.primary)

            Text("Helps calculate bodyweight exercise load. You can add it later in the Me screen.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280)

            Button {
                includesBodyWeight = true
                Haptics.selection()
            } label: {
                Label("Add body weight", systemImage: "plus")
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                    .padding(.horizontal, Space.lg)
                    .frame(minHeight: Space.tapMin)
            }
            .buttonStyle(.plain)
            .coloredGlassControl(cornerRadius: Radius.pill)
            .padding(.top, Space.lg)
            .accessibilityIdentifier("onboardingAddBodyWeightButton")
            .accessibilityHint("Shows an adjustable body weight")
        }
    }

    private var bodyWeightStepControl: some View {
        bodyWeightStepButton
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// The compact cycling increment control from Active Workout, tuned
    /// to scale precision instead of plate jumps.
    private var bodyWeightStepButton: some View {
        let options = weightUnit.bodyWeightStepOptions
        let label = WeightUnit.stepLabel(bodyWeightStep, unit: weightUnit.symbol)
        return Button {
            let index = options.firstIndex(of: bodyWeightStep) ?? 0
            let next = options[(index + 1) % options.count]
            Haptics.selection()
            bodyWeightStep = next
            snapBodyWeight(to: next, unit: weightUnit)
        } label: {
            Text(label)
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: Space.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: Space.sm) {
                        ForEach(WeightUnit.allCases) { unit in
                            unitChip(unit)
                        }
                    }
                } else {
                    HStack(spacing: Space.sm) {
                        ForEach(WeightUnit.allCases) { unit in
                            unitChip(unit)
                        }
                    }
                }
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 360 : 260)
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

    private var onboardingActions: some View {
        VStack(spacing: Space.md) {
            Button {
                includesBodyWeight = false
                Haptics.selection()
            } label: {
                Text("Not now")
                    .font(Typography.headline)
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, minHeight: Space.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .coloredGlassControl(cornerRadius: Radius.chip)
            .accessibilityIdentifier("onboardingNotNowButton")
            .accessibilityHint("Continues setup without recording body weight")
            .modifier(OnboardingStateVisibility(isVisible: includesBodyWeight))

            startButton
        }
    }

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
        .accessibilityIdentifier("onboardingStartButton")
        .disabled(isSaving)
        .opacity(isSaving ? Opacity.medium : 1)
        .accessibilityHint(
            includesBodyWeight
                ? "Records body weight and opens the app"
                : "Opens the app without recording body weight"
        )
    }

    // MARK: - Setup state

    private func hydrate() {
        if let latest = bodyWeightEntries.first {
            bodyWeight = latest.weight
            includesBodyWeight = true
        }
        bodyWeightStep = weightUnit.bodyWeightStep
        snapBodyWeight(to: bodyWeightStep, unit: weightUnit)
    }

    private func prepareFeedback() async {
        // Commit the first frame before warming feedback. Audio buffers decode
        // on a utility task, so preparation cannot hold up either toggle.
        await Task.yield()
        Haptics.prepare()
    }

    private func snapBodyWeight(to step: Double, unit: WeightUnit) {
        let displayed = WeightFormatter.toDisplay(bodyWeight, unit: unit)
        let snapped = (displayed / step).rounded() * step
        bodyWeight = WeightFormatter.toCanonical(snapped, unit: unit)
    }

    private func saveAndStart() {
        guard !isSaving else { return }
        guard !includesBodyWeight || (bodyWeight.isFinite && bodyWeight > 0) else { return }
        isSaving = true
        Haptics.soft()

        guard includesBodyWeight else {
            onStart()
            return
        }

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

/// Keeps both onboarding states in the render tree from the first frame.
/// Toggling body-weight entry then changes only presentation and interaction;
/// it does not synchronously construct and compile a new glass-heavy subtree.
private struct OnboardingStateVisibility: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .disabled(!isVisible)
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
