//
//  SettingsInteractionPolicyTests.swift
//  vivobodyTests
//
//  Guards Settings defaults, visible option order, entitlement rows, and
//  ordered preference/HealthKit commands without invoking system services.
//

import Testing
@testable import vivobody

struct SettingsInteractionPolicyTests {
    @Test func defaultsAndRestOrderMatchTheAppContract() {
        #expect(SettingsInteractionPolicy.defaults == SettingsPreferenceDefaults(
            appearance: .system,
            bodyDriftSpeed: .low,
            weightUnit: .lb,
            defaultRestSeconds: 120,
            hapticsEnabled: true,
            soundsEnabled: true,
            healthKitEnabled: false
        ))
        #expect(SettingsInteractionPolicy.restOptions == [180, 120, 90, 60, 30])
        #expect(SettingsInteractionPolicy.restOptions.contains(
            SettingsInteractionPolicy.defaults.defaultRestSeconds
        ))
    }

    @Test func optionSelectionsKeepFeedbackBeforeMutation() {
        #expect(SettingsInteractionPolicy.selectAppearance(.dark) == [
            .playSelectionHaptic,
            .setAppearance(.dark),
        ])
        #expect(SettingsInteractionPolicy.selectBodyDriftSpeed(.high) == [
            .playSelectionHaptic,
            .setBodyDriftSpeed(.high),
        ])
        #expect(SettingsInteractionPolicy.selectWeightUnit(.kg) == [
            .playSelectionHaptic,
            .setWeightUnit(.kg),
        ])
        #expect(SettingsInteractionPolicy.selectDefaultRest(90) == [
            .playSelectionHaptic,
            .setDefaultRestSeconds(90),
        ])
    }

    @Test func enablingHapticsWritesBeforeConfirmation() {
        #expect(SettingsInteractionPolicy.setHaptics(true) == [
            .setHapticsEnabled(true),
            .playSoftHaptic(playsSound: true),
        ])
        #expect(SettingsInteractionPolicy.setHaptics(false) == [
            .setHapticsEnabled(false),
        ])
    }

    @Test func enablingSoundsWritesBeforeIndependentAudioConfirmation() {
        #expect(SettingsInteractionPolicy.setSounds(true) == [
            .setSoundsEnabled(true),
            .playButtonSound,
        ])
        #expect(SettingsInteractionPolicy.setSounds(false) == [
            .setSoundsEnabled(false),
        ])
    }

    @Test func soundAndHapticPlansDoNotMutateEachOther() {
        let haptics = SettingsInteractionPolicy.setHaptics(true)
        #expect(!haptics.contains(.setSoundsEnabled(true)))
        #expect(!haptics.contains(.playButtonSound))

        let sounds = SettingsInteractionPolicy.setSounds(true)
        #expect(!sounds.contains(.setHapticsEnabled(true)))
        #expect(!sounds.contains(.playSoftHaptic(playsSound: true)))
    }

    @Test func proPresentationMatchesEntitlement() {
        #expect(SettingsInteractionPolicy.proPresentation(isUnlocked: false) == .locked)
        #expect(SettingsInteractionPolicy.proPresentation(isUnlocked: true) == .unlocked)
    }

    @Test func healthKitPresentationCoversAvailabilityAndEntitlement() {
        #expect(SettingsInteractionPolicy.healthKitPresentation(
            isAvailable: false,
            isPro: false
        ) == .unavailable)
        #expect(SettingsInteractionPolicy.healthKitPresentation(
            isAvailable: false,
            isPro: true
        ) == .unavailable)
        #expect(SettingsInteractionPolicy.healthKitPresentation(
            isAvailable: true,
            isPro: false
        ) == .locked)
        #expect(SettingsInteractionPolicy.healthKitPresentation(
            isAvailable: true,
            isPro: true
        ) == .unlocked)
    }

    @Test func disablingHealthKitDoesNotRequestAuthorization() {
        #expect(SettingsInteractionPolicy.disableHealthKit() == [
            .setHealthKitEnabled(false),
        ])
    }

    @Test func firstHealthKitEnableWritesThenShowsPrimer() {
        #expect(SettingsInteractionPolicy.beginHealthKitEnable() == [
            .setHealthKitEnabled(true),
        ])
        #expect(SettingsInteractionPolicy.routeHealthKitEnable(shouldPrime: true) == [
            .showHealthKitPriming(true),
        ])
    }

    @Test func subsequentHealthKitEnableWritesThenRequestsDirectly() {
        #expect(SettingsInteractionPolicy.beginHealthKitEnable() == [
            .setHealthKitEnabled(true),
        ])
        #expect(SettingsInteractionPolicy.routeHealthKitEnable(shouldPrime: false) == [
            .requestHealthKitAuthorization,
        ])
    }

    @Test func healthKitPrimerActionsPreserveExistingOrder() {
        #expect(SettingsInteractionPolicy.continueHealthKitPriming() == [
            .showHealthKitPriming(false),
            .requestHealthKitAuthorization,
        ])
        #expect(SettingsInteractionPolicy.declineHealthKitPriming() == [
            .setHealthKitEnabled(false),
            .showHealthKitPriming(false),
        ])
    }

    @Test func authorizationSettlementReflectsGrantWithoutAudio() {
        #expect(SettingsInteractionPolicy.settleHealthKitAuthorization(granted: true) == [
            .setHealthKitEnabled(true),
            .playSoftHaptic(playsSound: false),
        ])
        #expect(SettingsInteractionPolicy.settleHealthKitAuthorization(granted: false) == [
            .setHealthKitEnabled(false),
        ])
    }

    @Test func resetRequestConfirmsOnlyAfterFeedback() {
        #expect(SettingsInteractionPolicy.requestCatalogReset() == [
            .playSoftHaptic(playsSound: true),
            .showCatalogResetConfirmation,
        ])
    }
}
