//
//  SettingsInteractionPolicyTests.swift
//  vivobodyTests
//
//  Guards Settings defaults, visible option order, and ordered preference
//  commands without invoking system services.
//

import Testing
@testable import vivobody
import VivoKitSnapshotCore

struct SettingsInteractionPolicyTests {
    @Test func defaultsAndRestOrderMatchTheAppContract() {
        #expect(SettingsInteractionPolicy.defaults == SettingsPreferenceDefaults(
            appearance: .system,
            bodyDriftSpeed: .low,
            weightUnit: .lb,
            defaultRestSeconds: 120,
            hapticsEnabled: true,
            soundsEnabled: true
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

    @Test func resetRequestConfirmsOnlyAfterFeedback() {
        #expect(SettingsInteractionPolicy.requestCatalogReset() == [
            .playSoftHaptic(playsSound: true),
            .showCatalogResetConfirmation,
        ])
    }
}
