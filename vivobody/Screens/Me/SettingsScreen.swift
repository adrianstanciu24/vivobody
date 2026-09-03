//
//  SettingsScreen.swift
//  vivobody
//
//  Settings orchestration pushed from Me. This root owns UserDefaults,
//  StoreKit and HealthKit routing, catalog reset, alerts, sheets, URL/mail
//  presentation, and the footer. Focused sections receive only immutable
//  presentation, bindings, and actions.
//

import SwiftData
import SwiftUI
import VivoKit

struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProStore.self) private var pro: ProStore?
    @Environment(\.openURL) private var openURL

    @AppStorage(SettingsKey.hapticsEnabled)
    private var hapticsEnabled: Bool = SettingsDefaults.hapticsEnabled

    @AppStorage(SettingsKey.soundsEnabled)
    private var soundsEnabled: Bool = SettingsDefaults.soundsEnabled

    @AppStorage(SettingsKey.defaultRestSeconds)
    private var defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds

    @AppStorage(SettingsKey.weightUnit)
    private var weightUnitRaw: String = SettingsDefaults.weightUnit

    @AppStorage(SettingsKey.appearance)
    private var appearanceRaw: String = SettingsDefaults.appearance

    @AppStorage(SettingsKey.healthKitEnabled)
    private var healthKitEnabled: Bool = SettingsDefaults.healthKitEnabled

    @AppStorage(SettingsKey.bodyDriftSpeed)
    private var bodyDriftSpeedRaw: String = SettingsDefaults.bodyDriftSpeed

    @State private var isConfirmingCatalogReset: Bool = false
    @State private var catalogSaveError: SaveErrorBox?
    @State private var showHealthKitPriming: Bool = false
    @State private var activePage: WebPage?
    @State private var isComposingSupportMail: Bool = false

    private var isPro: Bool {
        pro?.isUnlocked == true
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    private var bodyDriftSpeed: BodyDriftSpeed {
        BodyDriftSpeed(rawValue: bodyDriftSpeedRaw) ?? .low
    }

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsProSection(
                    presentation: SettingsInteractionPolicy.proPresentation(isUnlocked: isPro),
                    onUnlock: requestProUnlock
                )
                .settleIn(0)

                SettingsPreferencesSection(
                    appearance: appearanceBinding,
                    bodyDriftSpeed: bodyDriftSpeedBinding,
                    weightUnit: weightUnitBinding,
                    defaultRestSeconds: defaultRestBinding,
                    hapticsEnabled: hapticsBinding,
                    soundsEnabled: soundsBinding,
                    healthKitEnabled: healthKitBinding,
                    restOptions: SettingsInteractionPolicy.restOptions,
                    healthKitPresentation: SettingsInteractionPolicy.healthKitPresentation(
                        isAvailable: HealthKitWorkoutService.isAvailable,
                        isPro: isPro
                    ),
                    bundledExerciseCount: CatalogData.records.count,
                    onRequestUnlock: requestProUnlock,
                    onRequestCatalogReset: requestCatalogReset
                )
                .padding(.top, Space.section)
                .settleIn(1)

                SettingsAboutSection(
                    onOpenPrivacyPolicy: { open(PublicLinks.privacyPolicy) },
                    onComposeSupportMail: composeSupportMail
                )
                .padding(.top, Space.section)
                .settleIn(2)

                footer
                    .padding(.top, Space.xxl)
                    .settleIn(3)
            }
            .padding(.top, Space.sm)
            .padding(.bottom, Space.section + Space.md)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Exercise Catalog?", isPresented: $isConfirmingCatalogReset) {
            Button("Reset", role: .destructive) {
                do {
                    try CatalogMutationBoundary(context: modelContext).resetToDefaults()
                } catch {
                    catalogSaveError = SaveErrorBox(error)
                    return
                }
                Haptics.thunk()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restores the \(CatalogData.records.count) bundled exercises. Any custom exercises and edits will be removed. Templates and workout history are not affected.")
        }
        .saveErrorAlert($catalogSaveError)
        .sheet(isPresented: $showHealthKitPriming) {
            HealthKitPrimingSheet(
                onContinue: {
                    perform(SettingsInteractionPolicy.continueHealthKitPriming())
                },
                onNotNow: {
                    perform(SettingsInteractionPolicy.declineHealthKitPriming())
                }
            )
        }
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

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appearance },
            set: { perform(SettingsInteractionPolicy.selectAppearance($0)) }
        )
    }

    private var bodyDriftSpeedBinding: Binding<BodyDriftSpeed> {
        Binding(
            get: { bodyDriftSpeed },
            set: { perform(SettingsInteractionPolicy.selectBodyDriftSpeed($0)) }
        )
    }

    private var weightUnitBinding: Binding<WeightUnit> {
        Binding(
            get: { weightUnit },
            set: { perform(SettingsInteractionPolicy.selectWeightUnit($0)) }
        )
    }

    private var defaultRestBinding: Binding<Int> {
        Binding(
            get: { defaultRestSeconds },
            set: { perform(SettingsInteractionPolicy.selectDefaultRest($0)) }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { hapticsEnabled },
            set: { perform(SettingsInteractionPolicy.setHaptics($0)) }
        )
    }

    private var soundsBinding: Binding<Bool> {
        Binding(
            get: { soundsEnabled },
            set: { perform(SettingsInteractionPolicy.setSounds($0)) }
        )
    }

    private var healthKitBinding: Binding<Bool> {
        Binding(
            get: { healthKitEnabled },
            set: { isEnabled in
                guard isEnabled else {
                    perform(SettingsInteractionPolicy.disableHealthKit())
                    return
                }
                perform(SettingsInteractionPolicy.beginHealthKitEnable())
                perform(SettingsInteractionPolicy.routeHealthKitEnable(
                    shouldPrime: HealthKitWorkoutService.shouldPrime
                ))
            }
        )
    }

    private func requestProUnlock() {
        perform(SettingsInteractionPolicy.requestProUnlock())
    }

    private func requestCatalogReset() {
        perform(SettingsInteractionPolicy.requestCatalogReset())
    }

    private func requestHealthKitAuthorization() async {
        let granted = await HealthKitWorkoutService.requestAuthorization()
        perform(SettingsInteractionPolicy.settleHealthKitAuthorization(granted: granted))
    }

    private func perform(_ commands: [SettingsInteractionCommand]) {
        for command in commands {
            if applyFeedback(command) { continue }
            if applyPreference(command) { continue }
            applyOrchestration(command)
        }
    }

    private func applyFeedback(_ command: SettingsInteractionCommand) -> Bool {
        switch command {
        case .playSelectionHaptic:
            Haptics.selection()
        case let .playSoftHaptic(playsSound):
            Haptics.soft(playsSound: playsSound)
        case .playButtonSound:
            Sounds.playButton()
        default:
            return false
        }
        return true
    }

    private func applyPreference(_ command: SettingsInteractionCommand) -> Bool {
        switch command {
        case let .setAppearance(value):
            appearanceRaw = value.rawValue
        case let .setBodyDriftSpeed(value):
            bodyDriftSpeedRaw = value.rawValue
        case let .setWeightUnit(value):
            weightUnitRaw = value.rawValue
        case let .setDefaultRestSeconds(value):
            defaultRestSeconds = value
        case let .setHapticsEnabled(value):
            hapticsEnabled = value
        case let .setSoundsEnabled(value):
            soundsEnabled = value
        case let .setHealthKitEnabled(value):
            healthKitEnabled = value
        default:
            return false
        }
        return true
    }

    private func applyOrchestration(_ command: SettingsInteractionCommand) {
        switch command {
        case .requestProUnlock:
            pro?.requestUnlock()
        case .showCatalogResetConfirmation:
            isConfirmingCatalogReset = true
        case let .showHealthKitPriming(isPresented):
            showHealthKitPriming = isPresented
        case .requestHealthKitAuthorization:
            Task { await requestHealthKitAuthorization() }
        default:
            assertionFailure("Unhandled Settings interaction command")
        }
    }

    private func open(_ url: URL) {
        if let page = WebPage(url) {
            activePage = page
        } else {
            openURL(url)
        }
    }

    private func composeSupportMail() {
        if MailComposeView.canSend {
            isComposingSupportMail = true
        } else if let url = SupportMail.mailtoURL {
            openURL(url)
        }
    }

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
