//
//  DebugSeedRoutingTests.swift
//  vivobodyTests
//
//  Guards pure DEBUG launch routing, fixture precedence, deterministic archive
//  timing, and idempotence without launching the app or invoking UI automation.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody
import VivoKit

#if DEBUG

    @MainActor
    struct DebugSeedRoutingTests {
        @Test func requestedTabUsesOnlyTheImmediateValidValue() {
            #expect(UITestSupport.route(arguments: ["app", "--verify-tab", "me"]).requestedTab == .me)
            #expect(UITestSupport.route(arguments: ["app", "--verify-tab"]).requestedTab == nil)
            #expect(UITestSupport.route(arguments: ["app", "--verify-tab", "settings"]).requestedTab == nil)
            #expect(UITestSupport.route(arguments: [
                "app", "--verify-tab", "unknown", "--verify-tab", "today",
            ]).requestedTab == nil)
        }

        @Test func resetRetainsTheOnboardingInversion() {
            #expect(UITestSupport.route(arguments: ["app"]).resetRequest == nil)
            #expect(UITestSupport.route(arguments: [
                "app", "--ui-test-reset",
            ]).resetRequest == DebugStoreResetRequest(shouldShowOnboarding: false))
            #expect(UITestSupport.route(arguments: [
                "app", "--ui-test-reset", "--ui-test-onboarding",
            ]).resetRequest == DebugStoreResetRequest(shouldShowOnboarding: true))
            #expect(UITestSupport.route(arguments: [
                "app", "--ui-test-onboarding",
            ]).resetRequest == nil)
        }

        @Test func launchStepsPreserveTheCompleteHistoricalDispatchOrder() {
            let arguments = [
                "app",
                "--ui-test-active-replaceable",
                "--ui-test-active-zero-set",
                "--ui-test-active-assistance",
                "--ui-test-completion-restoration",
                "--ui-test-skip-active-rest",
                "--ui-test-active-partial",
                "--ui-test-receipt-summary",
                "--ui-test-active-bodyweight",
                "--ui-test-active-bodyweight-duration",
                "--ui-test-active-band",
                "--ui-test-active-no-load",
                "--ui-test-active-ab-wheel",
                "--ui-test-superset",
                "--ui-test-superset-history",
                "--ui-test-superset-power",
                "--ui-test-single-exercise-history",
                "--ui-test-insights-empty-instruments",
                "--ui-test-insights-showcase",
                "--ui-test-insights-hard-sets",
                "--ui-test-me-showcase",
                "--ui-test-scheduled-template",
                "--ui-test-widget-start-request",
                "--ui-test-weekly-volume",
            ]

            #expect(UITestSupport.route(arguments: arguments).launchSteps == [
                .exerciseSubstitution(DebugExerciseSubstitutionRequest(
                    seedsReplacement: true,
                    seedsEmptyState: true
                )),
                .activeAssistance,
                .completionRestoration,
                .skipActiveRest,
                .activePartial(showsReceiptSummary: true),
                .activeBodyweight,
                .activeBodyweightDuration,
                .activeLoadPresentation(.abWheel),
                .activeSuperset,
                .supersetHistory,
                .activeSupersetPower,
                .singleExerciseHistory,
                .insightsEmptyInstruments,
                .insightsShowcase,
                .insightsHardSets,
                .meShowcase,
                .scheduledTemplate,
                .widgetStartRequest,
                .weeklyVolume,
            ])
        }

        @Test func activeLoadFlagsKeepAbWheelThenNoLoadThenBandPrecedence() {
            #expect(steps(for: ["--ui-test-active-band"]) == [
                .activeLoadPresentation(.band),
            ])
            #expect(steps(for: [
                "--ui-test-active-band", "--ui-test-active-no-load",
            ]) == [.activeLoadPresentation(.noLoad)])
            #expect(steps(for: [
                "--ui-test-active-band",
                "--ui-test-active-no-load",
                "--ui-test-active-ab-wheel",
            ]) == [.activeLoadPresentation(.abWheel)])
        }

        @Test func receiptSummaryOnlyDecoratesThePartialWorkoutFixture() {
            #expect(steps(for: ["--ui-test-receipt-summary"]).isEmpty)
            #expect(steps(for: [
                "--ui-test-active-partial", "--ui-test-receipt-summary",
            ]) == [.activePartial(showsReceiptSummary: true)])
        }

        @Test func manualFixturesRemainExclusiveInOriginalPrecedence() {
            #expect(manualFixture(for: ["--seed-templates"]) == .templates)
            #expect(manualFixture(for: ["--seed-pr", "--seed-templates"]) == .personalRecord)
            #expect(manualFixture(for: [
                "--seed-showcase", "--seed-pr", "--seed-templates",
            ]) == .showcase)
            #expect(manualFixture(for: [
                "--seed-history", "--seed-showcase", "--seed-pr", "--seed-templates",
            ]) == .history)
            #expect(manualFixture(for: []) == nil)
        }

        @Test func presentationArgumentsStayRoutedWithoutCreatingFixtures() {
            let route = UITestSupport.route(arguments: [
                "app",
                "--ui-test-strength-routine-builder",
                "--ui-test-custom-exercise-editor",
                "--static-body",
                "--pro",
                "--no-iap",
            ])
            #expect(route.opensStrengthRoutineBuilder)
            #expect(route.opensCustomExerciseEditor)
            #expect(route.launchSteps.isEmpty)
            #expect(route.manualFixture == nil)
        }

        @Test func partialFixtureWinsByOrderAndRemainsIdempotent() throws {
            let container = try makeContainer()
            let context = container.mainContext
            let steps: [DebugLaunchStep] = [
                .activePartial(showsReceiptSummary: true),
                .activeBodyweight,
            ]

            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)
            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)

            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let session = try #require(sessions.first)
            #expect(sessions.count == 1)
            #expect(session.activeExerciseIndex == 1)
            #expect(session.orderedExercises.map(\.name) == ["Barbell Bench Press"])
            #expect(session.orderedExercises.first?.orderedSets.count == 2)
            #expect(session.orderedExercises.first?.orderedSets.map(\.isCompleted) == [true, false])
        }

        @Test func resetClearsEveryStoreFamilyAndExternalFixtureKey() throws {
            let container = try makeContainer()
            let context = container.mainContext
            context.insert(WorkoutSession())
            context.insert(WorkoutTemplate(name: "Fixture"))
            context.insert(BodyWeightEntry(weight: 180))
            context.insert(ExerciseCatalogItem(
                name: "Fixture",
                group: .chest,
                defaultWeight: 0,
                isUserCreated: true
            ))
            try context.saveOrRollback()

            let defaultsName = "DebugSeedRoutingTests.defaults.\(UUID().uuidString)"
            let sharedName = "DebugSeedRoutingTests.shared.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: defaultsName))
            let sharedDefaults = try #require(UserDefaults(suiteName: sharedName))
            defer {
                defaults.removePersistentDomain(forName: defaultsName)
                sharedDefaults.removePersistentDomain(forName: sharedName)
            }
            CatalogDeletionTombstones.record("fixture", in: defaults)
            sharedDefaults.set(1, forKey: WidgetShared.startWorkoutRequestKey)
            sharedDefaults.set(1, forKey: WidgetShared.completeSetRequestKey)
            sharedDefaults.set(1, forKey: WidgetShared.startTemplateWorkoutRequestKey)

            DebugStoreResetter.reset(
                ifRequested: DebugStoreResetRequest(shouldShowOnboarding: true),
                in: context,
                defaults: defaults,
                sharedDefaults: sharedDefaults
            )

            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
            let bodyWeights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
            let catalogItems = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
            #expect(sessions.isEmpty)
            #expect(templates.isEmpty)
            #expect(bodyWeights.isEmpty)
            #expect(catalogItems.isEmpty)
            #expect(defaults.bool(forKey: SettingsKey.onboardingCompleted) == false)
            #expect(CatalogDeletionTombstones.ids(in: defaults).isEmpty)
            #expect(sharedDefaults.object(forKey: WidgetShared.startWorkoutRequestKey) == nil)
            #expect(sharedDefaults.object(forKey: WidgetShared.completeSetRequestKey) == nil)
            #expect(sharedDefaults.object(forKey: WidgetShared.startTemplateWorkoutRequestKey) == nil)
        }

        @Test func generalHistoryHasFixedDurationsAndKeepsDayFourteenContained() throws {
            let container = try makeContainer()
            let context = container.mainContext
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
            let now = try #require(calendar.date(from: DateComponents(
                year: 2026,
                month: 9,
                day: 2,
                hour: 23,
                minute: 59
            )))

            DebugArchivedHistorySeeder.seedGeneral(
                in: context,
                now: now,
                calendar: calendar
            )
            DebugArchivedHistorySeeder.seedGeneral(
                in: context,
                now: now,
                calendar: calendar
            )

            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let durations = sessions.compactMap { session in
                session.completedAt?.timeIntervalSince(session.startedAt)
            }
            #expect(sessions.count == 10)
            #expect(durations == Array(repeating: 45 * 60, count: 10))

            let targetDay = try #require(calendar.date(
                byAdding: .day,
                value: -14,
                to: calendar.startOfDay(for: now)
            ))
            let dayFourteen = try #require(sessions.first { session in
                calendar.isDate(session.startedAt, inSameDayAs: targetDay)
            })
            let completedAt = try #require(dayFourteen.completedAt)
            #expect(calendar.isDate(dayFourteen.startedAt, inSameDayAs: completedAt))
            #expect(calendar.component(.hour, from: dayFourteen.startedAt) == 18)
            #expect(calendar.component(.hour, from: completedAt) == 18)
        }

        @Test func scheduledTemplateFixtureIsIdempotent() throws {
            let container = try makeContainer()
            let context = container.mainContext
            let steps: [DebugLaunchStep] = [.scheduledTemplate]

            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)
            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)

            let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
            let template = try #require(templates.first)
            #expect(templates.count == 1)
            #expect(template.name == "Scheduled Test")
            #expect(template.orderedExercises.map(\.name) == ["Barbell Bench Press"])
            #expect(template.orderedExercises.first?.effectiveSetCount == 2)
        }

        @Test func insightsEmptyFixtureIsIdempotent() throws {
            let container = try makeContainer()
            let context = container.mainContext
            let steps: [DebugLaunchStep] = [.insightsEmptyInstruments]

            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)
            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)

            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let session = try #require(sessions.first)
            let exercise = try #require(session.orderedExercises.first)
            #expect(sessions.count == 1)
            #expect(exercise.name == "Box Jump")
            #expect(exercise.orderedSets.map(\.isCompleted) == [true])
            let duration = try #require(
                session.completedAt?.timeIntervalSince(session.startedAt)
            )
            #expect(abs(duration - 25 * 60) < 1e-9)
        }

        @Test func insightsHardSetFixtureIsIdempotentAndSelectsFallbackMeasure() throws {
            let container = try makeContainer()
            let context = container.mainContext
            let steps: [DebugLaunchStep] = [.insightsHardSets]

            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)
            DebugSeedCoordinator.seedLaunchFixtures(steps, in: context)

            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let sets = sessions.flatMap(\.orderedExercises).flatMap(\.orderedSets)
            #expect(sessions.count == 20)
            #expect(!sets.isEmpty)
            #expect(sets.allSatisfy { $0.isCompleted && $0.weight == 0 })
            #expect(sessions.trainingLoad().measure == .hardSets)
        }

        @Test func meShowcaseUsesOneClockAndNeverSeedsFutureWeight() throws {
            let container = try makeContainer()
            let context = container.mainContext
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
            let now = try #require(calendar.date(from: DateComponents(
                year: 2026,
                month: 9,
                day: 3,
                hour: 3
            )))

            MeShowcaseSeed.seed(in: context, now: now, calendar: calendar)
            MeShowcaseSeed.seed(in: context, now: now, calendar: calendar)

            let bodyWeights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
            #expect(bodyWeights.count == 3)
            #expect(bodyWeights.allSatisfy { $0.date <= now })
            #expect(bodyWeights.map(\.weight).sorted() == [177.6, 178.8, 180])
        }

        private func steps(for arguments: [String]) -> [DebugLaunchStep] {
            UITestSupport.route(arguments: ["app"] + arguments).launchSteps
        }

        private func manualFixture(for arguments: [String]) -> DebugManualFixture? {
            UITestSupport.route(arguments: ["app"] + arguments).manualFixture
        }

        private func makeContainer() throws -> ModelContainer {
            try VivobodyStore.makeContainer(
                named: "DebugSeedRoutingTests-\(UUID().uuidString)",
                isStoredInMemoryOnly: true
            )
        }
    }

#endif
