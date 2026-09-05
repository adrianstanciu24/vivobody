//
//  DebugSeed.swift
//  vivobody
//
//  Pure DEBUG launch-argument routing. Store mutation and fixture construction
//  live in focused seeders so parsing stays deterministic and directly tested.
//

import Foundation

#if DEBUG

    struct UITestRoute: Equatable {
        let requestedTab: AppTab?
        let resetRequest: DebugStoreResetRequest?
        let launchSteps: [DebugLaunchStep]
        let manualFixture: DebugManualFixture?
        let opensStrengthRoutineBuilder: Bool
        let opensCustomExerciseEditor: Bool
    }

    struct DebugStoreResetRequest: Equatable {
        let shouldShowOnboarding: Bool
    }

    struct DebugExerciseSubstitutionRequest: Equatable {
        let seedsReplacement: Bool
        let seedsEmptyState: Bool
    }

    enum DebugActiveLoadFixture: Equatable {
        case band
        case noLoad
        case abWheel
    }

    enum DebugLaunchStep: Equatable {
        case exerciseSubstitution(DebugExerciseSubstitutionRequest)
        case activeAssistance
        case completionRestoration
        case skipActiveRest
        case activePartial(showsReceiptSummary: Bool)
        case activeCompleteSummary
        case activeBodyweight
        case activeBodyweightDuration
        case activeLoadPresentation(DebugActiveLoadFixture)
        case activeSuperset
        case supersetHistory
        case activeSupersetPower
        case singleExerciseHistory
        case insightsEmptyInstruments
        case insightsShowcase
        case insightsDimensions
        case insightsHardSets
        case meShowcase
        case scheduledTemplate
        case widgetStartRequest
        case weeklyVolume
    }

    enum DebugManualFixture: Equatable {
        case history
        case showcase
        case personalRecord
        case templates
    }

    /// Converts launch arguments into immutable intent only. Callers decide
    /// when to perform reset, seeding, navigation, or presentation effects.
    enum UITestSupport {
        static func route(arguments: [String] = CommandLine.arguments) -> UITestRoute {
            let argumentSet = Set(arguments)
            return UITestRoute(
                requestedTab: requestedTab(in: arguments),
                resetRequest: resetRequest(in: argumentSet),
                launchSteps: launchSteps(in: argumentSet),
                manualFixture: manualFixture(in: argumentSet),
                opensStrengthRoutineBuilder: argumentSet.contains("--ui-test-strength-routine-builder"),
                opensCustomExerciseEditor: argumentSet.contains("--ui-test-custom-exercise-editor")
            )
        }

        static func requestedTab(arguments: [String] = CommandLine.arguments) -> AppTab? {
            requestedTab(in: arguments)
        }

        private static func requestedTab(in arguments: [String]) -> AppTab? {
            guard let index = arguments.firstIndex(of: "--verify-tab"),
                  arguments.indices.contains(index + 1)
            else { return nil }
            return AppTab(rawValue: arguments[index + 1])
        }

        private static func resetRequest(in arguments: Set<String>) -> DebugStoreResetRequest? {
            guard arguments.contains("--ui-test-reset") else { return nil }
            return DebugStoreResetRequest(
                shouldShowOnboarding: arguments.contains("--ui-test-onboarding")
            )
        }

        private static func launchSteps(in arguments: Set<String>) -> [DebugLaunchStep] {
            initialActiveSteps(in: arguments)
                + trailingLaunchSteps(in: arguments)
        }

        private static func initialActiveSteps(in arguments: Set<String>) -> [DebugLaunchStep] {
            [
                substitutionStep(in: arguments),
                requested(.activeAssistance, by: "--ui-test-active-assistance", in: arguments),
                requested(.completionRestoration, by: "--ui-test-completion-restoration", in: arguments),
                requested(.skipActiveRest, by: "--ui-test-skip-active-rest", in: arguments),
                activePartialStep(in: arguments),
                requested(
                    .activeCompleteSummary,
                    by: "--ui-test-active-complete-summary",
                    in: arguments
                ),
                requested(.activeBodyweight, by: "--ui-test-active-bodyweight", in: arguments),
                requested(
                    .activeBodyweightDuration,
                    by: "--ui-test-active-bodyweight-duration",
                    in: arguments
                ),
                activeLoadStep(in: arguments),
                requested(.activeSuperset, by: "--ui-test-superset", in: arguments),
            ].compactMap(\.self)
        }

        private static func trailingLaunchSteps(in arguments: Set<String>) -> [DebugLaunchStep] {
            [
                requested(.supersetHistory, by: "--ui-test-superset-history", in: arguments),
                requested(.activeSupersetPower, by: "--ui-test-superset-power", in: arguments),
                requested(
                    .singleExerciseHistory,
                    by: "--ui-test-single-exercise-history",
                    in: arguments
                ),
                requested(
                    .insightsEmptyInstruments,
                    by: "--ui-test-insights-empty-instruments",
                    in: arguments
                ),
                requested(.insightsShowcase, by: "--ui-test-insights-showcase", in: arguments),
                requested(.insightsDimensions, by: "--ui-test-insights-dimensions", in: arguments),
                requested(.insightsHardSets, by: "--ui-test-insights-hard-sets", in: arguments),
                requested(.meShowcase, by: "--ui-test-me-showcase", in: arguments),
                requested(.scheduledTemplate, by: "--ui-test-scheduled-template", in: arguments),
                requested(.widgetStartRequest, by: "--ui-test-widget-start-request", in: arguments),
                requested(.weeklyVolume, by: "--ui-test-weekly-volume", in: arguments),
            ].compactMap(\.self)
        }

        private static func substitutionStep(
            in arguments: Set<String>
        ) -> DebugLaunchStep? {
            let request = DebugExerciseSubstitutionRequest(
                seedsReplacement: arguments.contains("--ui-test-active-replaceable"),
                seedsEmptyState: arguments.contains("--ui-test-active-zero-set")
            )
            guard request.seedsReplacement || request.seedsEmptyState else { return nil }
            return .exerciseSubstitution(request)
        }

        private static func activePartialStep(in arguments: Set<String>) -> DebugLaunchStep? {
            guard arguments.contains("--ui-test-active-partial") else { return nil }
            return .activePartial(
                showsReceiptSummary: arguments.contains("--ui-test-receipt-summary")
            )
        }

        private static func activeLoadStep(in arguments: Set<String>) -> DebugLaunchStep? {
            if arguments.contains("--ui-test-active-ab-wheel") {
                return .activeLoadPresentation(.abWheel)
            }
            if arguments.contains("--ui-test-active-no-load") {
                return .activeLoadPresentation(.noLoad)
            }
            return requested(
                .activeLoadPresentation(.band),
                by: "--ui-test-active-band",
                in: arguments
            )
        }

        private static func manualFixture(in arguments: Set<String>) -> DebugManualFixture? {
            let requests: [(String, DebugManualFixture)] = [
                ("--seed-history", .history),
                ("--seed-showcase", .showcase),
                ("--seed-pr", .personalRecord),
                ("--seed-templates", .templates),
            ]
            return requests.first { arguments.contains($0.0) }?.1
        }

        private static func requested(
            _ step: DebugLaunchStep,
            by argument: String,
            in arguments: Set<String>
        ) -> DebugLaunchStep? {
            arguments.contains(argument) ? step : nil
        }
    }

#endif
