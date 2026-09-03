//
//  ExerciseDetailReadModelTrainingReports.swift
//  vivobody
//
//  Pure Exercise Detail projections for actionable training reports:
//  effort, progression cadence, weekly volume, and their complete
//  accessibility-ready text.
//

import Foundation

extension ExerciseDetailReadModel {
    @MainActor
    static func weeklyVolume(
        contribution: ExerciseVolumeContribution?,
        stats: [MuscleVolumeStat]
    ) -> WeeklyVolume? {
        weeklyVolume(
            contribution: contribution,
            statsByMuscle: Dictionary(
                uniqueKeysWithValues: stats.map { ($0.muscle, $0) }
            )
        )
    }

    @MainActor
    static func effort(
        _ summary: ExerciseEffortSummary?,
        exercise: ExerciseDescriptor
    ) -> Effort? {
        guard exercise.supportsEstimatedOneRepMax, let summary else {
            return nil
        }
        let average = String(format: "RIR %.1f", summary.avgRIR)
        let setNoun = summary.lastSessionSetCount == 1 ? "set" : "sets"
        let last = "Last · \(summary.lastSessionSetCount) \(setNoun)"
        let headline = summary.verdict.headline(for: exercise.loadMode)
        let verdictText = headline.map {
            ". \($0.replacingOccurrences(of: " · ", with: ", "))"
        } ?? ""
        return Effort(
            averageRIR: summary.avgRIR,
            averageText: average,
            lastSessionSetCount: summary.lastSessionSetCount,
            lastSessionText: last,
            lifetimeLoggedSetCount: summary.loggedSetCount,
            verdict: summary.verdict,
            headline: headline,
            accessibilityLabel: "Effort. Average RIR \(oneDecimal(summary.avgRIR)) across \(summary.lastSessionSetCount) \(setNoun) in the last rated session\(verdictText). Based on \(summary.loggedSetCount) logged RIR readings."
        )
    }

    @MainActor
    static func cadence(
        _ cadence: ProgressionCadence?,
        unit: WeightUnit
    ) -> Cadence? {
        guard let cadence else { return nil }
        let allEvents = cadence.events.map {
            LoadEvent(date: $0.date, load: $0.load)
        }
        let visible = Array(allEvents.suffix(cadenceEventLimit))
        let currentGap = dayCountText(
            cadence.daysSinceLastIncrease,
            todayText: "Today"
        )
        let currentDetail: String
        if cadence.daysSinceLastIncrease == 0 {
            currentDetail = "New load best"
        } else if cadence.daysSinceLastIncrease < cadence.medianGapDays {
            currentDetail = "Within your usual interval"
        } else if cadence.daysSinceLastIncrease == cadence.medianGapDays {
            currentDetail = "At your usual interval"
        } else {
            let beyond = cadence.daysSinceLastIncrease - cadence.medianGapDays
            currentDetail = "\(dayCountText(beyond)) longer than usual"
        }
        let count = cadence.increases.count
        let evidenceBase = "Based on \(count) \(count == 1 ? "increase" : "increases")"
        let evidence = cadence.isEarlyRead
            ? "\(evidenceBase) · early read"
            : evidenceBase
        let first = WeightFormatter.string(
            visible.first?.load ?? cadence.baseline.load,
            unit: unit,
            includeUnit: false
        )
        let last = WeightFormatter.string(
            visible.last?.load ?? cadence.baseline.load,
            unit: unit,
            includeUnit: false
        )
        let currentSentence = cadence.daysSinceLastIncrease == 0
            ? "The latest increase was today"
            : "It has been \(dayCountText(cadence.daysSinceLastIncrease)) since the last increase"
        let rangeContext = allEvents.count > cadenceEventLimit
            ? "Recent visible load bests"
            : "Visible load bests"
        let firstAccessible = WeightFormatter.string(
            visible.first?.load ?? cadence.baseline.load,
            unit: unit
        )
        let lastAccessible = WeightFormatter.string(
            visible.last?.load ?? cadence.baseline.load,
            unit: unit
        )
        return Cadence(
            visibleEvents: visible,
            showsRecentSubset: allEvents.count > cadenceEventLimit,
            medianGapDays: cadence.medianGapDays,
            daysSinceLastIncrease: cadence.daysSinceLastIncrease,
            isPastUsualRhythm: cadence.isPastUsualRhythm,
            isEarlyRead: cadence.isEarlyRead,
            usualPaceText: "~\(cadence.medianGapDays)",
            currentGapText: currentGap,
            currentDetailText: currentDetail,
            evidenceText: evidence,
            loadRangeText: "\(first) → \(last) \(unit.symbol)",
            accessibilityLabel: "Load cadence. New load bests are about \(dayCountText(cadence.medianGapDays)) apart. \(currentSentence), \(currentDetail.lowercased()). \(evidence.replacingOccurrences(of: " · ", with: ", ")). \(rangeContext) run from \(firstAccessible) to \(lastAccessible)."
        )
    }

    @MainActor
    static func weeklyVolume(
        contribution: ExerciseVolumeContribution?,
        statsByMuscle: [Muscle: MuscleVolumeStat]
    ) -> WeeklyVolume? {
        guard let contribution else { return nil }
        let rows = contribution.shares.prefix(weeklyVolumeRowLimit).map { share in
            let stat = statsByMuscle[share.muscle]
            let landmark = stat?.landmark ?? .default
            let total = max(stat?.effectiveSets ?? share.sets, share.sets)
            let role = share.role.map { ", \($0.displayName.lowercased())" } ?? ""
            let contributionText = "\(setsLabel(share.sets)) hard sets from this exercise this week"
            let accessibility: String
            if let stat {
                let band = "\(Int(landmark.mev)) to \(Int(landmark.optimalHigh))"
                let zone = switch stat.zone {
                case .untrained: "with no other work this week"
                case .under: "below the \(band) productive band"
                case .optimal: "inside the \(band) productive band"
                case .high: "above the \(band) productive band"
                }
                accessibility = "\(share.muscle.displayName)\(role). \(contributionText). \(setsLabel(stat.effectiveSets)) total this week, \(zone)."
            } else {
                accessibility = "\(share.muscle.displayName)\(role). \(contributionText)."
            }
            return WeeklyVolumeRow(
                muscle: share.muscle,
                role: share.role,
                contributionSets: share.sets,
                totalSets: total,
                landmark: landmark,
                zone: stat?.zone,
                contributionText: "+\(setsLabel(share.sets))",
                totalText: setsLabel(total),
                accessibilityLabel: accessibility
            )
        }
        guard !rows.isEmpty else { return nil }
        let landmark = contribution.shares.compactMap { statsByMuscle[$0.muscle] }
            .first?.landmark ?? .default
        let band = "\(Int(landmark.mev))–\(Int(landmark.optimalHigh))"
        return WeeklyVolume(
            rows: rows,
            bandText: band,
            caption: "Hard sets from this exercise in the last 7 days. Bars show each muscle's full week against its \(band) productive band."
        )
    }

    static func setsLabel(_ value: Double) -> String {
        value <= 0 ? "0" : String(format: "%.1f", value)
    }

    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func dayCountText(
        _ days: Int,
        todayText: String? = nil
    ) -> String {
        if days == 0, let todayText { return todayText }
        return "\(days) \(days == 1 ? "day" : "days")"
    }
}
