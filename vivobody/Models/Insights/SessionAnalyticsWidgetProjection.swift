//
//  SessionAnalyticsWidgetProjection.swift
//  vivobody
//
//  Pure projection from core session analytics into versioned widget
//  snapshots, without traversing SwiftData or replaying the archive.
//

import Foundation
import VivoKit

extension SessionAnalytics {
    nonisolated static func makeWidgetReports(
        core: CoreReports
    ) -> WidgetReports {
        let consistency = core.consistency
        let consistencySnapshot = ConsistencySnapshot(
            weeks: consistency.weeks.map { column in
                column.map {
                    ConsistencyDaySnapshot(
                        date: $0.date,
                        level: $0.level,
                        isInRange: $0.isInRange,
                        isToday: $0.isToday
                    )
                }
            },
            sessionsPerWeek: consistency.sessionsPerWeek,
            weekStreak: consistency.weekStreak,
            averageRIR: consistency.averageRIR,
            daysTrained: consistency.daysTrainedInWindow,
            weeklyVolume: consistency.weeks.map { column in
                column.filter(\.isInRange).reduce(0) { $0 + $1.sets }
            }
        )

        let signature = TrainingSignature(
            groupVolume: core.groupVolume,
            cadence: core.overview.averageWorkoutsPerWeek
        )
        let signatureSnapshot: SignatureSnapshot = if signature.hasSignature {
            SignatureSnapshot(
                petals: signature.petals.map {
                    SignaturePetalSnapshot(
                        group: $0.group.displayName,
                        volumeShare: $0.volumeShare
                    )
                },
                cadence: signature.cadence,
                balance: signature.balance,
                dominantGroup: signature.dominantGroup?.displayName,
                hasSignature: true,
                verdictLine: signatureVerdict(signature)
            )
        } else {
            .empty
        }

        return WidgetReports(
            consistency: consistencySnapshot,
            signature: signatureSnapshot,
            trainingLoad: trainingLoadSnapshot(core.load),
            load: core.load
        )
    }

    private nonisolated static func trainingLoadSnapshot(
        _ report: TrainingLoadReport
    ) -> TrainingLoadSnapshot {
        let range = report.recentRange
        let measure: TrainingLoadSnapshot.Measure = switch report.measure {
        case .volumeLoad: .volumeLoad
        case .hardSets: .hardSets
        }
        let verdict: TrainingLoadSnapshot.Verdict = switch report.verdict {
        case .insufficient: .insufficient
        case .low: .low
        case .productive: .within
        case .high: .high
        }
        return TrainingLoadSnapshot(
            measure: measure,
            currentLoad: report.currentLoad,
            verdict: verdict,
            rangeLower: range?.lowerBound,
            rangeUpper: range?.upperBound,
            observedBaselineDays: report.observedBaselineDays,
            activeBaselineWeeks: report.activeBaselineWeeks,
            points: report.points.suffix(TrainingLoadSnapshot.maxPoints).map {
                TrainingLoadPointSnapshot(
                    date: $0.date,
                    load: $0.load,
                    rangeLower: $0.rangeLower,
                    rangeUpper: $0.rangeUpper
                )
            }
        )
    }

    private nonisolated static func signatureVerdict(
        _ signature: TrainingSignature
    ) -> String {
        "\(signature.identityLine). \(InsightsFormat.perWeekLabel(signature.cadence))x/week all-time average."
    }
}
