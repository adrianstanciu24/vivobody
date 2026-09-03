//
//  TrainingLoad.swift
//  vivobody
//
//  The personal workload lens for Insights. When recent history contains
//  comparable load, the instrument uses rolling volume load (effective
//  load × reps in canonical pounds), folded with the same eligibility and
//  availability rules as History. Otherwise it falls back to completed
//  hard sets from `SetStimulus` so bodyweight-only and unweighted histories
//  retain a useful read. The muscle surfaces continue to use hard sets;
//  Training Load intentionally measures systemic work when load is known.
//
//  The headline compares the rolling last seven calendar days with
//  the median of the four non-overlapping weeks immediately before
//  them. A personal recent range of 0.8...1.3 times that median gives
//  relative context; it is not a clinical recovery, productivity, or
//  injury-risk claim.
//
//  The trend contains up to 84 daily points. Every point uses the
//  trailing seven days and, where enough prior history exists, its
//  own historical recent range. Pure value-type computation on
//  injected dates and calendars (see `TrainingLoadTests`).
//

import Foundation

// MARK: - Verdict

nonisolated enum LoadVerdict: Hashable {
    case insufficient
    /// Below the user's recent four-week range.
    case low
    /// Within the user's recent four-week range. The case name remains
    /// stable for source compatibility; UI copy calls this "within."
    case productive
    /// Above the user's recent four-week range.
    case high

    /// Recent-range band for current ÷ four-week median load. Single
    /// source of truth — the report's absolute range and every gauge
    /// derive from these bounds.
    static let recentRatioBand: ClosedRange<Double> = 0.8 ... 1.3

    /// Compatibility spelling for existing non-Insights consumers.
    static var productiveRatioBand: ClosedRange<Double> {
        recentRatioBand
    }

    static func from(ratio: Double) -> LoadVerdict {
        switch ratio {
        case ..<recentRatioBand.lowerBound: .low
        case ...recentRatioBand.upperBound: .productive
        default: .high
        }
    }
}

nonisolated enum TrainingLoadMeasure: Hashable {
    case volumeLoad
    case hardSets
}

// MARK: - Trend and drivers

/// One daily sample of the rolling seven-day load.
nonisolated struct LoadPoint: Identifiable, Hashable {
    var id: Date {
        date
    }

    let date: Date
    let load: Double
    let productiveLower: Double?
    let productiveUpper: Double?

    /// Recent-range spellings used by current UI. Stored-property names
    /// remain stable for snapshots and existing callers.
    var rangeLower: Double? {
        productiveLower
    }

    var rangeUpper: Double? {
        productiveUpper
    }
}

/// One calendar day's selected Training Load measure — the per-day
/// (not rolling) sample behind the Today readiness strip. `trained`
/// remains true when qualifying work has missing comparable load.
nonisolated struct DayLoad: Identifiable, Hashable {
    var id: Date {
        date
    }

    let date: Date
    let load: Double
    private let hasQualifyingWork: Bool

    var trained: Bool {
        hasQualifyingWork
    }

    init(date: Date, load: Double, trained: Bool? = nil) {
        self.date = date
        self.load = load
        hasQualifyingWork = trained ?? (load > 0)
    }

    /// Very short weekday symbol ("M", "T", …) for day-strip labels.
    func weekdayInitial(calendar: Calendar = .current) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}

nonisolated struct LoadDriver: Hashable {
    let current: Double
    let usual: Double?
}

nonisolated struct TrainingLoadDrivers: Hashable {
    let volumeLoad: LoadDriver
    let hardSets: LoadDriver
    /// Completed sessions carrying either Training Load currency.
    let sessions: LoadDriver
    let heavySets: LoadDriver
    let moderateSets: LoadDriver

    static let empty = TrainingLoadDrivers(
        volumeLoad: LoadDriver(current: 0, usual: nil),
        hardSets: LoadDriver(current: 0, usual: nil),
        sessions: LoadDriver(current: 0, usual: nil),
        heavySets: LoadDriver(current: 0, usual: nil),
        moderateSets: LoadDriver(current: 0, usual: nil)
    )
}

// MARK: - Report

nonisolated struct TrainingLoadReport: Hashable {
    /// Minimum observation span before the four-week comparison settles.
    static let baselineMinimumDays = 28
    /// At least three of the four prior weeks must contain qualifying work.
    static let requiredActiveBaselineWeeks = 3

    /// The currency used by the headline, trend, strip, and verdict.
    let measure: TrainingLoadMeasure
    /// Completeness of comparable load in the rolling current window.
    let loadAvailability: ComparableTonnageAvailability
    /// Selected load in the rolling last seven days.
    let currentLoad: Double
    /// Median weekly load across the four preceding weeks.
    let usualLoad: Double?
    /// Current load divided by usual load. Zero while forming.
    let ratio: Double
    /// Early comparison against the median active prior week. This
    /// powers a provisional gauge marker before the four-week personal
    /// baseline is stable; nil when no prior week exists or once the
    /// stable ratio is available.
    let provisionalRatio: Double?
    let verdict: LoadVerdict
    /// Whole calendar days from first completed work to `now`.
    let daysLogged: Int
    /// Prior non-overlapping weeks containing work in the selected measure.
    let activeBaselineWeeks: Int
    /// Rolling seven-day load over at most the trailing 12 weeks.
    let points: [LoadPoint]
    /// Per-day loads for the trailing seven calendar days, oldest
    /// first and ending today. Untrained days appear with zero load.
    let recentDays: [DayLoad]
    let drivers: TrainingLoadDrivers

    /// Explicit initializer keeps existing fixtures source-compatible
    /// while allowing analytics to expose concrete baseline progress.
    init(
        currentLoad: Double,
        usualLoad: Double?,
        ratio: Double,
        provisionalRatio: Double?,
        verdict: LoadVerdict,
        daysLogged: Int,
        activeBaselineWeeks: Int = 0,
        points: [LoadPoint],
        recentDays: [DayLoad],
        drivers: TrainingLoadDrivers,
        measure: TrainingLoadMeasure = .hardSets,
        loadAvailability: ComparableTonnageAvailability = .complete
    ) {
        self.measure = measure
        self.loadAvailability = loadAvailability
        self.currentLoad = currentLoad
        self.usualLoad = usualLoad
        self.ratio = ratio
        self.provisionalRatio = provisionalRatio
        self.verdict = verdict
        self.daysLogged = daysLogged
        self.activeBaselineWeeks = activeBaselineWeeks
        self.points = points
        self.recentDays = recentDays
        self.drivers = drivers
    }

    var hasEnoughHistory: Bool {
        verdict != .insufficient
    }

    /// The best available position for compact visual gauges.
    var gaugeRatio: Double? {
        hasEnoughHistory ? ratio : provisionalRatio
    }

    var recentRange: ClosedRange<Double>? {
        guard let usualLoad else { return nil }
        let band = LoadVerdict.recentRatioBand
        return (usualLoad * band.lowerBound) ... (usualLoad * band.upperBound)
    }

    /// Compatibility spelling for existing non-Insights consumers.
    var productiveRange: ClosedRange<Double>? {
        recentRange
    }

    var observedBaselineDays: Int {
        min(Self.baselineMinimumDays, max(0, daysLogged))
    }

    var baselineDaysRemaining: Int {
        max(0, Self.baselineMinimumDays - daysLogged)
    }

    var baselineWeeksRemaining: Int {
        max(0, Self.requiredActiveBaselineWeeks - activeBaselineWeeks)
    }

    var changeFromUsual: Double? {
        guard let usualLoad, usualLoad > 0 else { return nil }
        return (currentLoad - usualLoad) / usualLoad
    }

    // MARK: Gauge geometry

    /// The compact gauges plot ratios on a 0…2× track.
    static let gaugeRatioSpan: Double = 2

    /// Fractional position (0…1) of a ratio along the gauge track.
    static func gaugePosition(forRatio ratio: Double) -> Double {
        min(1, max(0, ratio / gaugeRatioSpan))
    }

    /// The recent band mapped onto the gauge track.
    static var gaugeRecentBand: ClosedRange<Double> {
        let band = LoadVerdict.recentRatioBand
        return gaugePosition(forRatio: band.lowerBound) ... gaugePosition(forRatio: band.upperBound)
    }

    /// Compatibility spelling for existing non-Insights consumers.
    static var gaugeProductiveBand: ClosedRange<Double> {
        gaugeRecentBand
    }

    /// Marker position for the best available ratio; nil while no
    /// comparison exists at all.
    var gaugeMarkerPosition: Double? {
        gaugeRatio.map(Self.gaugePosition(forRatio:))
    }
}
