//
//  SettingsScreen.swift
//  vivobody
//
//  App configuration, pushed from the gear button on Me. Carries the
//  preference rows that used to live inline on MeScreen — appearance,
//  weight unit, default rest, haptics — plus the destructive Reset
//  Exercise Catalog action and the app footer.
//
//  Settings persist via @AppStorage (UserDefaults). The Haptics
//  engine reads its enabled flag directly from UserDefaults on every
//  emission, so toggling here takes effect immediately throughout
//  the app with no extra wiring. The weight unit follows the same
//  pattern — every display site and every weight scrubber reads
//  the unit at render time, so flipping the toggle propagates
//  instantly across the app.
//

import SwiftUI
import SwiftData

struct SettingsScreen: View {
    /// SwiftData context — needed for the Reset Catalog action,
    /// which wipes and re-seeds the ExerciseCatalogItem store.
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.hapticsEnabled)
    private var hapticsEnabled: Bool = SettingsDefaults.hapticsEnabled

    @AppStorage(SettingsKey.defaultRestSeconds)
    private var defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    @AppStorage(SettingsKey.appearance)
    private var appearanceRaw: String = SettingsDefaults.appearance

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    @AppStorage(SettingsKey.healthKitEnabled)
    private var healthKitEnabled: Bool = SettingsDefaults.healthKitEnabled

    /// Controls the destructive-confirmation alert for "Reset
    /// Exercise Catalog." Bound to the alert's `isPresented`.
    @State private var isConfirmingCatalogReset: Bool = false

    /// Common rest values that cover the bulk of strength-training
    /// programs. Surfaced as a horizontal chip selector — picking a
    /// value is a single tap with no keyboard or sheet round-trip.
    private let restOptions: [Int] = [30, 60, 90, 120, 180]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                preferencesSection
                    .settleIn(0)
                footer
                    .padding(.top, Space.xxl)
                    .settleIn(1)
            }
            .padding(.top, Space.sm)
            // Extra tail so the last row clears the floating tab bar
            // at rest instead of peeking out from under it.
            .padding(.bottom, Space.section + Space.md)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .detailForgeBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Preferences")

            VStack(alignment: .leading, spacing: Space.lg + 2) {
                appearanceRow
                rowDivider
                weightUnitRow
                rowDivider
                restRow
                rowDivider
                hapticsRow
                if HealthKitWorkoutService.isAvailable {
                    rowDivider
                    healthKitRow
                }
                rowDivider
                resetCatalogRow
            }
        }
        .alert(
            "Reset Exercise Catalog?",
            isPresented: $isConfirmingCatalogReset
        ) {
            Button("Reset", role: .destructive) {
                ExerciseCatalogItem.resetToDefaults(in: modelContext)
                SpotlightIndexer.reindexAll(
                    templates: (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? [],
                    items: (try? modelContext.fetch(FetchDescriptor<ExerciseCatalogItem>())) ?? []
                )
                Haptics.thunk()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Restores the original 90 exercises. Any custom exercises and edits will be removed. Templates and workout history are not affected.")
        }
    }

    /// Destructive-action row inside Preferences. Tapping the whole
    /// row opens a confirmation alert — never single-tap destructive,
    /// per the rest of the app's pattern (delete set, cancel
    /// workout, etc.).
    private var resetCatalogRow: some View {
        Button {
            Haptics.soft()
            isConfirmingCatalogReset = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Reset Exercise Catalog")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Restore the original 90 exercises")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
            .coloredGlassControl(cornerRadius: Radius.chip)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Wipes and reseeds the exercise catalog")
    }

    private var appearanceRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            // No trailing value label: the highlighted chip below is
            // the single source of selection state (all options are
            // always visible, so a separate readout would only echo it).
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Appearance")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Light, dark, or follow the system")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(AppAppearance.allCases) { option in
                        appearanceChip(option)
                    }
                }
            }
        }
    }

    private func appearanceChip(_ option: AppAppearance) -> some View {
        let isSelected = option == appearance
        return Button {
            Haptics.selection()
            appearanceRaw = option.rawValue
        } label: {
            Text(option.label)
                .font(Typography.sectionLabel)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .coloredGlassControl(cornerRadius: Radius.chip, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var weightUnitRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            // No trailing value label: the highlighted chip below
            // already carries the selection (both options visible).
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Weight Unit")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Displayed across the app — storage stays canonical")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(WeightUnit.allCases) { unit in
                        weightUnitChip(unit)
                    }
                }
            }
        }
    }

    private func weightUnitChip(_ unit: WeightUnit) -> some View {
        let isSelected = unit == weightUnit
        return Button {
            Haptics.selection()
            weightUnitRaw = unit.rawValue
        } label: {
            VStack(spacing: 2) {
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                Text(unit.displayName)
                    .font(Typography.micro)
                    .opacity(Opacity.emphasis)
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .coloredGlassControl(cornerRadius: Radius.chip, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unit.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Default Rest")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Between sets — used by the rest timer")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Text("\(defaultRestSeconds)s")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(restOptions, id: \.self) { seconds in
                            restChip(seconds: seconds)
                        }
                    }
                }
            }
        }
    }

    private func restChip(seconds: Int) -> some View {
        let isSelected = defaultRestSeconds == seconds
        return Button {
            Haptics.selection()
            defaultRestSeconds = seconds
        } label: {
            Text("\(seconds)s")
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minWidth: 56, minHeight: 44)
                .padding(.horizontal, Space.md + 2)
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(seconds) second rest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hapticsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Haptics")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Taps and patterns throughout the app")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { hapticsEnabled },
                set: { newValue in
                    hapticsEnabled = newValue
                    if newValue {
                        // The @AppStorage write propagates synchronously
                        // to UserDefaults, so the next Haptics emission
                        // reads `true` — this soft tap plays as a
                        // confirmation that haptics just came back on.
                        Haptics.soft()
                    }
                }
            ))
            .labelsHidden()
            .tint(Tint.inProgress)
        }
    }

    /// Apple Health opt-in. Enabling requests write authorization;
    /// the toggle settles to the real grant (reverts to off if the
    /// user declines). Only shown when HealthKit exists on the device
    /// — so it never appears in the Simulator.
    private var healthKitRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Apple Health")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Save finished workouts to the Health app")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { healthKitEnabled },
                set: { newValue in
                    // Optimistically reflect the tap so the switch
                    // doesn't snap back while the system sheet is up;
                    // settle to the real grant when it returns.
                    healthKitEnabled = newValue
                    guard newValue else { return }
                    Task {
                        let granted = await HealthKitWorkoutService.requestAuthorization()
                        healthKitEnabled = granted
                        if granted { Haptics.soft() }
                    }
                }
            ))
            .labelsHidden()
            .tint(Tint.inProgress)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Space.sm) {
            Text("vivobody")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.sm)
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .preferredColorScheme(.dark)
}
