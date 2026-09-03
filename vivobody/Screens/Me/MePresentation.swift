//
//  MePresentation.swift
//  vivobody
//
//  Immutable, model-free presentation snapshot for the Me dashboard. It
//  reduces cached archive reports, standing records, and a bounded newest-
//  first body-weight window into copy and values consumed by focused views.
//

import Foundation

nonisolated enum MePresentation: Hashable {
    case loading
    case dashboard(Dashboard)

    static let bodyWeightLimit = 30

    nonisolated struct Dashboard: Hashable {
        let journey: Journey
        let insights: Insights
        let milestones: [MilestoneItem]
        let records: Records
        let bodyWeight: BodyWeight
        let recap: Recap
    }

    nonisolated enum Journey: Hashable {
        case empty(EmptyJourney)
        case populated(JourneyHero)
    }

    nonisolated struct EmptyJourney: Hashable {
        let title: String
        let systemImage: String
        let detail: String
    }

    nonisolated struct JourneyHero: Hashable {
        let volume: Metric
        let lifetimeMetrics: [Metric]
        let lifetimeAccessibilityLabel: String
        let trainingAgeText: String?
    }

    nonisolated struct Insights: Hashable {
        let eyebrow: String
        let title: String
        let detail: String
        let accessibilityLabel: String
        let accessibilityHint: String
    }

    /// A deterministic render-position identity around milestone values. The
    /// domain `Milestone` creates a fresh UUID, while the dashboard has always
    /// retained tiles by their visible position so power-on motion does not
    /// restart whenever the reports refresh.
    nonisolated struct MilestoneItem: Identifiable, Hashable {
        let id: Int
        let icon: String
        let legend: String
        let valueLabel: String
        let targetLabel: String?
        let targetProgress: Double
        let achieved: Bool
        let featured: Bool

        var milestone: Milestone {
            Milestone(
                icon: icon,
                legend: legend,
                valueLabel: valueLabel,
                targetLabel: targetLabel,
                targetProgress: targetProgress,
                achieved: achieved
            )
        }
    }

    nonisolated struct Records: Hashable {
        let totalCount: Int
        let preview: [Record]

        var hasRecords: Bool {
            totalCount > 0
        }

        var trailingLabel: String? {
            totalCount > 3 ? "See all" : nil
        }
    }

    nonisolated struct Record: Identifiable, Hashable {
        let id: String
        let name: String
        let subtitle: String
        let headlineValue: String
        let qualifierValue: String?
        let valueAccessibilityLabel: String
        let isRecent: Bool
    }

    /// A SwiftData-free copy of one bounded body-weight query result. Weight
    /// remains canonical pounds until this presentation boundary formats it.
    nonisolated struct BodyWeightSample: Hashable {
        let date: Date
        let canonicalPounds: Double
    }

    nonisolated enum BodyWeight: Hashable {
        case empty(EmptyBodyWeight)
        case populated(BodyWeightSummary)

        var trailingLabel: String? {
            switch self {
            case .empty: nil
            case .populated: "View trend"
            }
        }
    }

    nonisolated struct EmptyBodyWeight: Hashable {
        let detail: String
        let actionLabel: String
    }

    nonisolated struct BodyWeightSummary: Hashable {
        let value: String
        let unit: String
        let delta: BodyWeightDelta?
        let firstEntryLabel: String?
        let sparkValues: [Double]
    }

    nonisolated struct BodyWeightDelta: Hashable {
        let label: String
        let isIncrease: Bool
    }

    nonisolated struct Recap: Hashable {
        let monthLabel: String
        let metrics: [Metric]
    }

    nonisolated struct Metric: Hashable {
        let value: String
        let unit: String?
        let label: String
        let accent: Bool

        var accessibilityLabel: String {
            "\(value)\(unit.map { " \($0)" } ?? "") \(label)"
        }
    }
}

extension MePresentation {
    @MainActor
    static func make(
        hasHistory: Bool,
        hasCoreReports: Bool,
        overview: ArchiveOverview,
        standingRecords: [ExerciseProgress],
        bodyWeightSamplesNewestFirst: [BodyWeightSample],
        unit: WeightUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MePresentation {
        guard !hasHistory || hasCoreReports else { return .loading }

        let records = makeRecords(
            standingRecords,
            unit: unit,
            now: now,
            calendar: calendar
        )
        return .dashboard(Dashboard(
            journey: makeJourney(
                hasHistory: hasHistory,
                overview: overview,
                recordCount: records.totalCount,
                unit: unit,
                now: now,
                calendar: calendar
            ),
            insights: Insights(
                eyebrow: "INSIGHTS",
                title: "Read your training",
                detail: "Load, strength, rhythm, and balance — one layer deeper.",
                accessibilityLabel: "Insights",
                accessibilityHint: "Opens analysis of your training load, strength, rhythm, and balance"
            ),
            milestones: makeMilestones(
                overview: overview,
                recordCount: records.totalCount,
                unit: unit
            ),
            records: records,
            bodyWeight: makeBodyWeight(
                bodyWeightSamplesNewestFirst,
                unit: unit
            ),
            recap: makeRecap(overview.monthlyRecap, unit: unit)
        ))
    }

    @MainActor
    private static func makeJourney(
        hasHistory: Bool,
        overview: ArchiveOverview,
        recordCount: Int,
        unit: WeightUnit,
        now: Date,
        calendar: Calendar
    ) -> Journey {
        guard hasHistory else {
            return .empty(EmptyJourney(
                title: "Log your first workout",
                systemImage: "flame",
                detail: "Your lifetime volume, workouts, and sets will land here."
            ))
        }

        let volume = volumeMetric(
            overview.lifetimeTonnage,
            unit: unit,
            completeLabel: "Total volume",
            partialLabel: "Known volume · total unavailable",
            unavailableLabel: "Volume unavailable"
        )
        let lifetimeMetrics = [
            Metric(
                value: "\(overview.totalWorkouts)",
                unit: nil,
                label: overview.totalWorkouts == 1 ? "workout" : "workouts",
                accent: false
            ),
            Metric(
                value: "\(overview.totalSets)",
                unit: nil,
                label: overview.totalSets == 1 ? "set" : "sets",
                accent: false
            ),
            Metric(
                value: "\(recordCount)",
                unit: nil,
                label: recordCount == 1 ? "PR" : "PRs",
                accent: recordCount > 0
            ),
        ]
        return .populated(JourneyHero(
            volume: volume,
            lifetimeMetrics: lifetimeMetrics,
            lifetimeAccessibilityLabel: "\(overview.totalWorkouts) workouts, \(overview.totalSets) sets, \(recordCount) personal records all time",
            trainingAgeText: JourneyFormatting.trainingAgeText(
                since: overview.trainingSince,
                now: now,
                calendar: calendar
            )
        ))
    }

    @MainActor
    private static func makeMilestones(
        overview: ArchiveOverview,
        recordCount: Int,
        unit: WeightUnit
    ) -> [MilestoneItem] {
        let milestones = JourneyMilestones.build(
            workouts: overview.totalWorkouts,
            tonnage: overview.lifetimeTonnage,
            longestStreak: overview.streak.longest,
            prCount: recordCount,
            unit: unit
        )
        var featuredIndex: Int?
        for index in milestones.indices {
            let candidate = milestones[index]
            guard !candidate.achieved, candidate.targetLabel != nil else { continue }
            guard let currentBest = featuredIndex else {
                featuredIndex = index
                continue
            }
            if candidate.targetProgress > milestones[currentBest].targetProgress {
                featuredIndex = index
            }
        }

        let orderedIndices: [Int] = if let featuredIndex {
            [featuredIndex]
                + milestones.indices.filter { $0 != featuredIndex }
        } else {
            Array(milestones.indices)
        }
        return orderedIndices.enumerated().map { position, index in
            let milestone = milestones[index]
            return MilestoneItem(
                id: position,
                icon: milestone.icon,
                legend: milestone.legend,
                valueLabel: milestone.valueLabel,
                targetLabel: milestone.targetLabel,
                targetProgress: milestone.targetProgress,
                achieved: milestone.achieved,
                featured: index == featuredIndex
            )
        }
    }

    @MainActor
    private static func makeRecords(
        _ standingRecords: [ExerciseProgress],
        unit: WeightUnit,
        now: Date,
        calendar: Calendar
    ) -> Records {
        Records(
            totalCount: standingRecords.count,
            preview: standingRecords.prefix(3).map {
                makeRecord($0, unit: unit, now: now, calendar: calendar)
            }
        )
    }

    @MainActor
    private static func makeRecord(
        _ record: ExerciseProgress,
        unit: WeightUnit,
        now: Date,
        calendar: Calendar
    ) -> Record {
        let point = record.recordPoint
        let headlineValue: String
        let qualifierValue: String?
        let valueAccessibilityLabel: String

        if let point {
            switch record.trackingMode {
            case .reps:
                headlineValue = point.loadMode.loggedLoadLabel(
                    point.topWeight,
                    unit: unit,
                    includeUnit: false
                ) ?? "—"
                qualifierValue = "× \(point.topReps)"
                let load = point.loadMode.loggedLoadLabel(
                    point.topWeight,
                    unit: unit,
                    includeUnit: true
                )
                valueAccessibilityLabel = load.map { "\($0) × \(point.topReps)" }
                    ?? "\(point.topReps) reps"
            case .duration:
                let loadWithoutUnit = point.performanceSemanticKind.comparesLoad
                    ? point.loadMode.loggedLoadLabel(
                        point.topWeight,
                        unit: unit,
                        includeUnit: false
                    )
                    : nil
                headlineValue = loadWithoutUnit
                    ?? DurationFormatter.string(point.topDuration)
                qualifierValue = loadWithoutUnit == nil
                    ? nil
                    : "× \(DurationFormatter.string(point.topDuration))"
                let time = DurationFormatter.string(point.topDuration)
                let load = point.performanceSemanticKind.comparesLoad
                    ? point.loadMode.loggedLoadLabel(
                        point.topWeight,
                        unit: unit,
                        includeUnit: true
                    )
                    : nil
                valueAccessibilityLabel = load.map { "\($0) × \(time)" } ?? time
            }
        } else {
            headlineValue = "—"
            qualifierValue = nil
            valueAccessibilityLabel = "—"
        }

        var subtitleParts = [record.group.displayName]
        if let date = record.recordDate {
            subtitleParts.append(RelativeDate.short(
                date,
                now: now,
                calendar: calendar
            ))
        }
        let cutoff = calendar.date(
            byAdding: .day,
            value: -30,
            to: now
        ) ?? .distantFuture
        return Record(
            id: record.id,
            name: record.name,
            subtitle: subtitleParts.joined(separator: " · "),
            headlineValue: headlineValue,
            qualifierValue: qualifierValue,
            valueAccessibilityLabel: valueAccessibilityLabel,
            isRecent: record.recordDate.map { $0 >= cutoff } ?? false
        )
    }

    @MainActor
    private static func makeBodyWeight(
        _ samplesNewestFirst: [BodyWeightSample],
        unit: WeightUnit
    ) -> BodyWeight {
        // Cap the newest-first query before reversing it for the chart. Doing
        // this in the opposite order would silently select the oldest values.
        let bounded = Array(samplesNewestFirst.prefix(bodyWeightLimit))
        guard let latest = bounded.first else {
            return .empty(EmptyBodyWeight(
                detail: "Track your body weight to see how it trends alongside your training.",
                actionLabel: "Log weight"
            ))
        }

        let delta: BodyWeightDelta?
        if bounded.count >= 2 {
            let change = latest.canonicalPounds - bounded[1].canonicalPounds
            delta = BodyWeightDelta(
                label: "\(WeightFormatter.deltaString(change, unit: unit, fractionDigits: 1)) since last entry",
                isIncrease: change > 0
            )
        } else {
            delta = nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return .populated(BodyWeightSummary(
            value: WeightFormatter.string(
                latest.canonicalPounds,
                unit: unit,
                fractionDigits: 1,
                includeUnit: false
            ),
            unit: unit.symbol,
            delta: delta,
            firstEntryLabel: delta == nil
                ? "First entry · \(formatter.string(from: latest.date))"
                : nil,
            sparkValues: bounded.reversed().map(\.canonicalPounds)
        ))
    }

    @MainActor
    private static func makeRecap(
        _ recap: MonthlyRecap,
        unit: WeightUnit
    ) -> Recap {
        Recap(
            monthLabel: recap.monthLabel,
            metrics: [
                Metric(
                    value: "\(recap.workouts)",
                    unit: nil,
                    label: recap.workouts == 1 ? "workout" : "workouts",
                    accent: false
                ),
                volumeMetric(
                    ComparableTonnageSummary(
                        knownSubtotal: recap.volume,
                        availability: recap.volumeAvailability
                    ),
                    unit: unit,
                    completeLabel: "volume",
                    partialLabel: "known volume",
                    unavailableLabel: "volume unavailable"
                ),
                Metric(
                    value: "\(recap.prs)",
                    unit: nil,
                    label: recap.prs == 1 ? "PR" : "PRs",
                    accent: recap.prs > 0
                ),
            ]
        )
    }

    @MainActor
    private static func volumeMetric(
        _ tonnage: ComparableTonnageSummary,
        unit: WeightUnit,
        completeLabel: String,
        partialLabel: String,
        unavailableLabel: String
    ) -> Metric {
        switch tonnage.availability {
        case .complete:
            Metric(
                value: WeightFormatter.volumeValue(
                    tonnage.knownSubtotal,
                    unit: unit
                ),
                unit: unit.symbol,
                label: completeLabel,
                accent: false
            )
        case .partial:
            Metric(
                value: "\(WeightFormatter.volumeValue(tonnage.knownSubtotal, unit: unit))+",
                unit: unit.symbol,
                label: partialLabel,
                accent: false
            )
        case .unavailable:
            Metric(
                value: "—",
                unit: nil,
                label: unavailableLabel,
                accent: false
            )
        }
    }
}
