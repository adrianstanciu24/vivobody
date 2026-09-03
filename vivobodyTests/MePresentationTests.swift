//
//  MePresentationTests.swift
//  vivobodyTests
//
//  Guards the Me dashboard's immutable presentation boundary: readiness,
//  journey totals, milestone ordering, standing-record previews, bounded
//  body-weight semantics, unit conversion, and monthly recap copy.
//

import Foundation
import Testing
@testable import vivobody

private nonisolated func requireMeSendable(
    _: (some Sendable).Type
) {}

@MainActor
struct MePresentationTests {
    private let now = Date(timeIntervalSince1970: 1_788_351_200)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: now)!
    }

    private func overview(
        totalWorkouts: Int = 0,
        totalSets: Int = 0,
        lifetimeTonnage: ComparableTonnageSummary = .zero,
        trainingSince: Date? = nil,
        longestStreak: Int = 0,
        recap: MonthlyRecap = MonthlyRecap(
            monthLabel: "September",
            workouts: 0,
            volume: 0,
            volumeAvailability: .complete,
            sets: 0,
            prs: 0
        )
    ) -> ArchiveOverview {
        ArchiveOverview(
            totalWorkouts: totalWorkouts,
            totalSets: totalSets,
            lifetimeTonnage: lifetimeTonnage,
            trainingSince: trainingSince,
            averageWorkoutsPerWeek: 0,
            streak: WorkoutStreak(
                current: longestStreak,
                longest: longestStreak
            ),
            monthlyRecap: recap,
            prSessionIDs: [],
            forgeWarmth: ForgeWarmth.idle
        )
    }

    private func record(
        name: String,
        daysAgo: Int = 2,
        weight: Double = 145,
        reps: Int = 8,
        duration: TimeInterval = 0,
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        tracksResistance: Bool = true,
        prEvents: Int = 1
    ) -> ExerciseProgress {
        let points = (0 ..< prEvents).map { index in
            var point = ExerciseProgressPoint(
                date: date(daysAgo: daysAgo + prEvents - 1 - index),
                topWeight: weight + Double(index),
                topReps: reps,
                topDuration: duration + Double(index),
                trackingMode: trackingMode,
                modality: modality,
                loadMode: loadMode,
                tracksResistance: tracksResistance,
                totalVolume: weight * Double(reps),
                comparableTonnageAvailability: .complete
            )
            point.isStrengthPR = true
            return point
        }
        return ExerciseProgress(
            catalogID: name.lowercased().replacingOccurrences(
                of: " ",
                with: "-"
            ),
            catalogItemID: nil,
            name: name,
            group: .chest,
            points: points
        )
    }

    private func dashboard(
        hasHistory: Bool = true,
        hasCoreReports: Bool = true,
        overview: ArchiveOverview? = nil,
        records: [ExerciseProgress] = [],
        bodyWeights: [MePresentation.BodyWeightSample] = [],
        unit: WeightUnit = .lb
    ) -> MePresentation.Dashboard {
        let presentation = MePresentation.make(
            hasHistory: hasHistory,
            hasCoreReports: hasCoreReports,
            overview: overview ?? self.overview(),
            standingRecords: records,
            bodyWeightSamplesNewestFirst: bodyWeights,
            unit: unit,
            now: now,
            calendar: calendar
        )
        guard case let .dashboard(dashboard) = presentation else {
            fatalError("Expected dashboard presentation")
        }
        return dashboard
    }

    @Test
    nonisolated func presentationValuesAreSendable() {
        requireMeSendable(MePresentation.self)
        requireMeSendable(MePresentation.Dashboard.self)
        requireMeSendable(MePresentation.BodyWeightSample.self)
    }

    @Test
    func loadingGateOnlyBlocksARealArchiveBeforeCoreReports() {
        let loading = MePresentation.make(
            hasHistory: true,
            hasCoreReports: false,
            overview: overview(),
            standingRecords: [],
            bodyWeightSamplesNewestFirst: [],
            unit: .lb,
            now: now,
            calendar: calendar
        )
        #expect(loading == .loading)

        let noHistory = dashboard(
            hasHistory: false,
            hasCoreReports: false
        )
        guard case let .empty(empty) = noHistory.journey else {
            Issue.record("No-history state should remain an empty dashboard")
            return
        }
        #expect(empty.title == "Log your first workout")
        #expect(empty.systemImage == "flame")
        #expect(
            empty.detail
                == "Your lifetime volume, workouts, and sets will land here."
        )
    }

    @Test
    func populatedJourneyUsesOverviewAndStandingRecordCount() throws {
        let trainingSince = try #require(calendar.date(
            byAdding: .year,
            value: -1,
            to: now
        ))
        let records = (0 ..< 9).map {
            record(name: "Lift \($0)", daysAgo: $0 + 1)
        }
        let dashboard = dashboard(
            overview: overview(
                totalWorkouts: 20,
                totalSets: 250,
                lifetimeTonnage: ComparableTonnageSummary(
                    knownSubtotal: 278_400,
                    availability: .complete
                ),
                trainingSince: trainingSince,
                longestStreak: 6
            ),
            records: records
        )

        guard case let .populated(hero) = dashboard.journey else {
            Issue.record("History should produce the journey hero")
            return
        }
        #expect(hero.volume.value == "278.4k")
        #expect(hero.volume.unit == "lb")
        #expect(hero.volume.label == "Total volume")
        #expect(hero.volume.accessibilityLabel == "278.4k lb Total volume")
        #expect(hero.lifetimeMetrics.map(\.value) == ["20", "250", "9"])
        #expect(hero.lifetimeMetrics.map(\.label) == ["workouts", "sets", "PRs"])
        #expect(hero.lifetimeMetrics.map(\.accent) == [false, false, true])
        #expect(
            hero.lifetimeAccessibilityLabel
                == "20 workouts, 250 sets, 9 personal records all time"
        )
        #expect(hero.trainingAgeText?.hasSuffix("· 1 year") == true)
    }

    @Test
    func recordSectionCoversZeroThreeAndFourStandingRecords() {
        let zero = dashboard(records: []).records
        #expect(!zero.hasRecords)
        #expect(zero.preview.isEmpty)
        #expect(zero.trailingLabel == nil)

        let three = dashboard(records: (0 ..< 3).map {
            record(name: "Three \($0)")
        }).records
        #expect(three.hasRecords)
        #expect(three.totalCount == 3)
        #expect(three.preview.count == 3)
        #expect(three.trailingLabel == nil)

        let four = dashboard(records: (0 ..< 4).map {
            record(name: "Four \($0)")
        }).records
        #expect(four.totalCount == 4)
        #expect(four.preview.map(\.name) == ["Four 0", "Four 1", "Four 2"])
        #expect(four.trailingLabel == "See all")
    }

    @Test
    func journeyCountsStandingRecordsRatherThanRecordEvents() {
        let dashboard = dashboard(records: [
            record(name: "Repeated PR Lift", prEvents: 3),
        ])

        #expect(dashboard.records.totalCount == 1)
        guard case let .populated(hero) = dashboard.journey else {
            Issue.record("History should produce the journey hero")
            return
        }
        #expect(hero.lifetimeMetrics.last?.value == "1")
        #expect(
            dashboard.milestones.first(where: { $0.legend == "PRs" })?
                .valueLabel == "1"
        )
    }

    @Test
    func recordPreviewPreservesRepAndDurationSemantics() {
        let reps = record(name: "Bench Press", daysAgo: 2)
        let unloadedHold = record(
            name: "Plank",
            daysAgo: 4,
            weight: 0,
            reps: 0,
            duration: 90,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .nonComparable,
            tracksResistance: false
        )
        let loadedHold = record(
            name: "Loaded Hold",
            daysAgo: 40,
            weight: 25,
            reps: 0,
            duration: 45,
            trackingMode: .duration,
            modality: .isometricStrength
        )
        let previews = dashboard(
            records: [reps, unloadedHold, loadedHold]
        ).records.preview

        #expect(previews[0].subtitle == "Chest · 2d ago")
        #expect(previews[0].headlineValue == "145")
        #expect(previews[0].qualifierValue == "× 8")
        #expect(previews[0].valueAccessibilityLabel == "145 lb × 8")
        #expect(previews[0].isRecent)

        #expect(previews[1].headlineValue == "1:30")
        #expect(previews[1].qualifierValue == nil)
        #expect(previews[1].valueAccessibilityLabel == "1:30")

        #expect(previews[2].headlineValue == "25")
        #expect(previews[2].qualifierValue == "× 0:45")
        #expect(previews[2].valueAccessibilityLabel == "25 lb × 0:45")
        #expect(!previews[2].isRecent)
    }

    @Test
    func equalMilestoneProgressKeepsDomainOrderAndPositionalIdentity() {
        let milestones = dashboard().milestones

        #expect(milestones.map(\.id) == [0, 1, 2, 3])
        #expect(
            milestones.map(\.legend)
                == ["Workouts", "Volume", "PRs", "Week streak"]
        )
        #expect(milestones.map(\.featured) == [true, false, false, false])
    }

    @Test
    func nearestUnfinishedMilestoneMovesFirstAndKeepsPositionalIdentity() {
        let milestones = dashboard(
            overview: overview(
                totalWorkouts: 1,
                totalSets: 1,
                lifetimeTonnage: ComparableTonnageSummary(
                    knownSubtotal: 1_000,
                    availability: .complete
                ),
                longestStreak: 3
            )
        ).milestones

        #expect(milestones.map(\.id) == [0, 1, 2, 3])
        #expect(
            milestones.map(\.legend)
                == ["Week streak", "Workouts", "Volume", "PRs"]
        )
        #expect(milestones.map(\.featured) == [true, false, false, false])
    }

    @Test
    func completedMilestonesKeepDomainOrderWithoutAFeaturedTile() {
        let records = (0 ..< 100).map {
            record(name: "Record \($0)", daysAgo: $0)
        }
        let milestones = dashboard(
            overview: overview(
                totalWorkouts: 1000,
                totalSets: 10000,
                lifetimeTonnage: ComparableTonnageSummary(
                    knownSubtotal: 5_000_000,
                    availability: .complete
                ),
                longestStreak: 52
            ),
            records: records
        ).milestones

        #expect(
            milestones.map(\.legend)
                == ["Workouts", "Volume", "PRs", "Week streak"]
        )
        #expect(milestones.map(\.achieved) == [true, true, true, true])
        #expect(milestones.map(\.featured) == [false, false, false, false])
        #expect(milestones.map(\.id) == [0, 1, 2, 3])
    }

    @Test
    func bodyWeightCoversEmptyAndFirstEntryStates() {
        guard case let .empty(empty) = dashboard().bodyWeight else {
            Issue.record("No samples should produce an empty body-weight card")
            return
        }
        #expect(empty.actionLabel == "Log weight")
        #expect(
            empty.detail
                == "Track your body weight to see how it trends alongside your training."
        )

        let sample = MePresentation.BodyWeightSample(
            date: date(daysAgo: 3),
            canonicalPounds: 180
        )
        let bodyWeight = dashboard(bodyWeights: [sample]).bodyWeight
        guard case let .populated(summary) = bodyWeight else {
            Issue.record("A sample should produce a populated card")
            return
        }
        let separator = Locale.current.decimalSeparator ?? "."
        #expect(bodyWeight.trailingLabel == "View trend")
        #expect(summary.value == "180\(separator)0")
        #expect(summary.unit == "lb")
        #expect(summary.delta == nil)
        #expect(summary.firstEntryLabel?.hasPrefix("First entry · ") == true)
        #expect(summary.sparkValues == [180])
    }

    @Test
    func bodyWeightUsesNewestVersusNextNewestAndFormatsKilograms() {
        let latest = MePresentation.BodyWeightSample(
            date: date(daysAgo: 0),
            canonicalPounds: 220.462262
        )
        let previous = MePresentation.BodyWeightSample(
            date: date(daysAgo: 1),
            canonicalPounds: 218.25763938
        )
        guard case let .populated(summary) = dashboard(
            bodyWeights: [latest, previous],
            unit: .kg
        ).bodyWeight else {
            Issue.record("Two samples should produce a populated card")
            return
        }

        let separator = Locale.current.decimalSeparator ?? "."
        #expect(summary.value == "100\(separator)0")
        #expect(summary.unit == "kg")
        #expect(summary.delta?.label == "+1\(separator)0 kg since last entry")
        #expect(summary.delta?.isIncrease == true)
        #expect(summary.firstEntryLabel == nil)
        #expect(
            summary.sparkValues
                == [previous.canonicalPounds, latest.canonicalPounds]
        )
    }

    @Test
    func bodyWeightCapsNewestWindowBeforeReversingForTheChart() {
        let samples = (0 ... MePresentation.bodyWeightLimit).map { index in
            MePresentation.BodyWeightSample(
                date: date(daysAgo: index),
                canonicalPounds: 200 - Double(index)
            )
        }
        guard case let .populated(summary) = dashboard(
            bodyWeights: samples
        ).bodyWeight else {
            Issue.record("Samples should produce a populated card")
            return
        }

        #expect(summary.sparkValues.count == MePresentation.bodyWeightLimit)
        #expect(summary.sparkValues.first == 171)
        #expect(summary.sparkValues.last == 200)
        let separator = Locale.current.decimalSeparator ?? "."
        #expect(summary.delta?.label == "+1\(separator)0 lb since last entry")
    }

    @Test
    func monthlyRecapPreservesPluralizationVolumeTruthAndAccessibility() {
        let complete = dashboard(overview: overview(recap: MonthlyRecap(
            monthLabel: "September",
            workouts: 1,
            volume: 12500,
            volumeAvailability: .complete,
            sets: 4,
            prs: 1
        ))).recap
        #expect(complete.monthLabel == "September")
        #expect(complete.metrics.map(\.label) == ["workout", "volume", "PR"])
        #expect(complete.metrics.map(\.accessibilityLabel) == [
            "1 workout",
            "12.5k lb volume",
            "1 PR",
        ])
        #expect(complete.metrics.map(\.accent) == [false, false, true])

        let partial = dashboard(overview: overview(recap: MonthlyRecap(
            monthLabel: "September",
            workouts: 2,
            volume: 8000,
            volumeAvailability: .partial,
            sets: 8,
            prs: 0
        ))).recap
        #expect(partial.metrics[0].label == "workouts")
        #expect(partial.metrics[1].value == "8,000+")
        #expect(partial.metrics[1].label == "known volume")
        #expect(
            partial.metrics[1].accessibilityLabel
                == "8,000+ lb known volume"
        )
        #expect(partial.metrics[2].label == "PRs")
        #expect(!partial.metrics[2].accent)

        let unavailable = dashboard(overview: overview(recap: MonthlyRecap(
            monthLabel: "September",
            workouts: 0,
            volume: 0,
            volumeAvailability: .unavailable,
            sets: 0,
            prs: 0
        ))).recap
        #expect(unavailable.metrics[1].value == "—")
        #expect(unavailable.metrics[1].unit == nil)
        #expect(
            unavailable.metrics[1].accessibilityLabel
                == "— volume unavailable"
        )
    }
}
