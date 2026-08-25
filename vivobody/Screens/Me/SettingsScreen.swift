//
//  SettingsScreen.swift
//  vivobody
//
//  App configuration, pushed from the gear button on Me. Carries the
//  preference rows that used to live inline on MeScreen — appearance,
//  model rotation, weight unit, default rest, haptics — plus the
//  destructive Reset Exercise Catalog action, the About links
//  (privacy policy and support, required for App Store
//  distribution), and the app footer.
//
//  Sections render as ledger blocks, matching History and Library:
//  the SectionHeader stays on black and the section's rows sit
//  together inside one shared content card with inset hairlines.
//  Glass stays reserved for the genuine controls — the option chips
//  and toggles inside the rows.
//
//  Settings persist via @AppStorage (UserDefaults). The Haptics
//  engine reads its enabled flag directly from UserDefaults on every
//  emission, so toggling here takes effect immediately throughout
//  the app with no extra wiring. The weight unit follows the same
//  pattern — every display site and every weight scrubber reads
//  the unit at render time, so flipping the toggle propagates
//  instantly across the app.
//

import SwiftData
import SwiftUI
import VivoKit

struct SettingsScreen: View {
    /// SwiftData context — needed for the Reset Catalog action,
    /// which wipes and re-seeds the ExerciseCatalogItem store.
    @Environment(\.modelContext) private var modelContext

    /// Pro entitlement, injected by AppRoot. Optional so previews
    /// still build — nil fails closed as free. Drives the Vivobody
    /// Pro row and the Apple Health gate.
    @Environment(ProStore.self) private var pro: ProStore?

    private var isPro: Bool {
        pro?.isUnlocked == true
    }

    @AppStorage(SettingsKey.hapticsEnabled)
    private var hapticsEnabled: Bool = SettingsDefaults.hapticsEnabled

    @AppStorage(SettingsKey.soundsEnabled)
    private var soundsEnabled: Bool = SettingsDefaults.soundsEnabled

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

    @AppStorage(SettingsKey.bodyDriftSpeed)
    private var bodyDriftSpeedRaw: String = SettingsDefaults.bodyDriftSpeed

    private var bodyDriftSpeed: BodyDriftSpeed {
        BodyDriftSpeed(rawValue: bodyDriftSpeedRaw) ?? .low
    }

    /// Controls the destructive-confirmation alert for "Reset
    /// Exercise Catalog." Bound to the alert's `isPresented`.
    @State private var isConfirmingCatalogReset: Bool = false

    /// Presents the Apple Health explainer before the first
    /// authorization prompt. Driven by the HealthKit toggle.
    @State private var showHealthKitPriming: Bool = false

    /// The About page currently open in the in-app browser. Non-nil
    /// presents the Safari sheet; Done clears it.
    @State private var activePage: WebPage?

    /// Presents the prefilled support email. Only ever set when the
    /// device can actually send mail.
    @State private var isComposingSupportMail: Bool = false

    /// Escape hatch for URLs the in-app surfaces cannot handle — a
    /// non-http page, or `mailto:` on a device without the composer.
    @Environment(\.openURL) private var openURL

    /// Common rest values that cover the bulk of strength-training
    /// programs. Surfaced as a horizontal chip selector — picking a
    /// value is a single tap with no keyboard or sheet round-trip.
    private let restOptions: [Int] = [180, 120, 90, 60, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                proSection
                    .settleIn(0)
                preferencesSection
                    .padding(.top, Space.section)
                    .settleIn(1)
                aboutSection
                    .padding(.top, Space.section)
                    .settleIn(2)
                footer
                    .padding(.top, Space.xxl)
                    .settleIn(3)
            }
            .padding(.top, Space.sm)
            // Extra tail so the last row clears the floating tab bar
            // at rest instead of peeking out from under it.
            .padding(.bottom, Space.section + Space.md)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activePage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isComposingSupportMail) {
            MailComposeView(
                recipient: SupportMail.recipient,
                subject: SupportMail.subject,
                body: SupportMail.body
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Vivobody Pro

    /// The one quiet Pro surface in Settings. Free → a tappable row
    /// that opens the paywall; owned → a static "Unlocked" row. No
    /// banners, no countdowns, nothing anywhere else.
    private var proSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Vivobody Pro")

            if isPro {
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Vivobody Pro")
                            .font(Typography.sectionHeading)
                            .foregroundStyle(Ink.primary)
                        Text("Unlocked — thank you")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(Typography.headline)
                        .foregroundStyle(Tint.primary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                .contentCard()
                .accessibilityElement(children: .combine)
            } else {
                Button {
                    pro?.requestUnlock()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("Unlock Vivobody Pro")
                                .font(Typography.sectionHeading)
                                .foregroundStyle(Ink.primary)
                            Text("Insights, progress charts, unlimited templates")
                                .font(Typography.caption)
                                .foregroundStyle(Ink.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Typography.sectionLabel)
                            .foregroundStyle(Ink.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.md)
                    .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                    // The one tappable promo on the screen wears the
                    // bright surface — the same lift History gives
                    // today's ledger card.
                    .contentCard(bright: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the Vivobody Pro purchase sheet")
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Preferences")

            VStack(alignment: .leading, spacing: 0) {
                appearanceRow
                rowDivider
                bodyDriftSpeedRow
                rowDivider
                weightUnitRow
                rowDivider
                restRow
                rowDivider
                hapticsRow
                rowDivider
                soundsRow
                if HealthKitWorkoutService.isAvailable {
                    rowDivider
                    healthKitRow
                }
                rowDivider
                resetCatalogRow
            }
            .contentCard()
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restores the \(bundledExerciseCount) bundled exercises. Any custom exercises and edits will be removed. Templates and workout history are not affected.")
        }
        .sheet(isPresented: $showHealthKitPriming) {
            HealthKitPrimingSheet(
                onContinue: {
                    showHealthKitPriming = false
                    Task { await requestHealthKitAuthorization() }
                },
                onNotNow: {
                    healthKitEnabled = false
                    showHealthKitPriming = false
                }
            )
        }
    }

    /// Destructive-action row — the Preferences card's last row.
    /// Tapping the whole row opens a confirmation alert — never
    /// single-tap destructive, per the rest of the app's pattern
    /// (delete set, cancel workout, etc.).
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
                    Text("Restore \(bundledExerciseCount) bundled exercises")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Wipes and reseeds the exercise catalog")
    }

    /// Reads the generated bundle instead of duplicating a count that drifts
    /// whenever the curated default roster changes.
    private var bundledExerciseCount: Int {
        CatalogData.records.count
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
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
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

    /// Idle rotation speed of the 3D figure on Today. Same chip
    /// vocabulary as Appearance — all three options visible, so the
    /// highlighted chip is the only readout needed.
    private var bodyDriftSpeedRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Model Rotation")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("How fast the body model turns on its own")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(BodyDriftSpeed.allCases) { option in
                        bodyDriftSpeedChip(option)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private func bodyDriftSpeedChip(_ option: BodyDriftSpeed) -> some View {
        let isSelected = option == bodyDriftSpeed
        return Button {
            Haptics.selection()
            bodyDriftSpeedRaw = option.rawValue
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
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
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
            .padding(.horizontal, Space.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(restOptions, id: \.self) { seconds in
                            restChip(seconds: seconds)
                        }
                    }
                }
                // The scroll clip must stay (scrolled-away chips may
                // not draw past the card), but a zero-height clip
                // slices off the glass material's soft light-mode
                // shadows into a hard-edged slab. Grow the clip
                // vertically so the shadows fade inside it, then pull
                // the layout back so the row's height doesn't change.
                .padding(.vertical, Space.md)
            }
            .padding(.vertical, -Space.md)
            // Chips inset like the other rows at rest, but scroll all
            // the way to the card's edges once the strip moves.
            .contentMargins(.horizontal, Space.lg, for: .scrollContent)
        }
        .padding(.vertical, Space.md)
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
            .accessibilityLabel("Haptics")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private var soundsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Sounds")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Synth blips paired with the haptics")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { soundsEnabled },
                set: { newValue in
                    soundsEnabled = newValue
                    if newValue {
                        // Same trick as the haptics row: the write is
                        // synchronous, so this click plays as audible
                        // confirmation that sounds just came back on.
                        Sounds.playButton()
                    }
                }
            ))
            .labelsHidden()
            .tint(Tint.inProgress)
            .accessibilityLabel("Sounds")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    /// Apple Health opt-in. Enabling requests write authorization;
    /// the toggle settles to the real grant (reverts to off if the
    /// user declines). Only shown when HealthKit exists on the device
    /// — so it never appears in the Simulator. Part of Pro: the free
    /// tier shows a lock in place of the toggle, and tapping the row
    /// opens the paywall.
    @ViewBuilder
    private var healthKitRow: some View {
        if isPro {
            unlockedHealthKitRow
        } else {
            Button {
                pro?.requestUnlock()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Apple Health")
                            .font(Typography.sectionHeading)
                            .foregroundStyle(Ink.primary)
                        Text("Save finished workouts to the Health app · Pro")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(Ink.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apple Health, part of Vivobody Pro")
            .accessibilityHint("Opens the Vivobody Pro purchase sheet")
        }
    }

    private var unlockedHealthKitRow: some View {
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
                    if HealthKitWorkoutService.shouldPrime {
                        showHealthKitPriming = true
                    } else {
                        Task { await requestHealthKitAuthorization() }
                    }
                }
            ))
            .labelsHidden()
            .tint(Tint.inProgress)
            .accessibilityLabel("Apple Health")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    /// Runs the HealthKit write-authorization request and settles the
    /// toggle to the real grant. Shared by the direct path (once the
    /// prompt has already been shown) and the priming sheet's Continue.
    private func requestHealthKitAuthorization() async {
        let granted = await HealthKitWorkoutService.requestAuthorization()
        healthKitEnabled = granted
        // Lands after the system prompt, with nothing pressed — the
        // grant deserves a nudge, not the button click.
        if granted { Haptics.soft(playsSound: false) }
    }

    /// In-card hairline between rows, inset so it never runs into
    /// the card's rounded corners — same treatment as History's
    /// ledger blocks.
    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
    }

    // MARK: - About

    /// The two contact points App Review expects to find in-app — the
    /// privacy policy (required for HealthKit apps) and a support
    /// channel.
    /// Neither contact point ejects the user: the policy renders in
    /// an in-app Safari sheet (`SafariView`) and support opens a
    /// prefilled composer (`MailComposeView`).
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "About")

            VStack(alignment: .leading, spacing: 0) {
                aboutRow(
                    title: "Privacy Policy",
                    subtitle: "Everything stays on your device",
                    icon: "arrow.up.right",
                    hint: "Opens in this app"
                ) {
                    open(PublicLinks.privacyPolicy)
                }
                rowDivider
                aboutRow(
                    title: "Contact & Support",
                    subtitle: "Questions, bugs, feature requests",
                    icon: "envelope",
                    hint: "Opens a new email"
                ) {
                    composeSupportMail()
                }
            }
            .contentCard()
        }
    }

    /// Opens a web page in the in-app browser, handing anything it
    /// cannot render (non-http schemes) to the system instead.
    private func open(_ url: URL) {
        if let page = WebPage(url) {
            activePage = page
        } else {
            openURL(url)
        }
    }

    /// Prefers the in-app composer. Devices with no mail account fall
    /// back to a `mailto:` URL so the row still does something rather
    /// than dead-ending on a tap.
    private func composeSupportMail() {
        if MailComposeView.canSend {
            isComposingSupportMail = true
        } else if let url = SupportMail.mailtoURL {
            openURL(url)
        }
    }

    private func aboutRow(
        title: String,
        subtitle: String,
        icon: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: icon)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
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
