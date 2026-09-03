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
            strength: strengthSnapshot(
                board: core.strength,
                progress: core.progress
            ),
            load: core.load
        )
    }

    private nonisolated static func strengthSnapshot(
        board: StrengthOutlookBoard,
        progress: [ExerciseProgress]
    ) -> StrengthSnapshot {
        guard let lead = board.stats.first else { return .empty }
        let series = progress.first { $0.id == lead.historyKey }
        var runningMax = -Double.infinity
        var points: [StrengthPointSnapshot] = []
        for point in series?.points ?? [] where point.estimated1RM > 0 {
            let isPR = point.estimated1RM > runningMax
            if isPR { runningMax = point.estimated1RM }
            points.append(
                StrengthPointSnapshot(
                    date: point.date,
                    e1RM: point.estimated1RM,
                    isPR: isPR
                )
            )
        }

        return StrengthSnapshot(
            exercise: lead.exercise,
            points: Array(points.suffix(StrengthSnapshot.maxPoints)),
            currentE1RM: lead.currentE1RM,
            bestE1RM: lead.bestE1RM,
            trendLabel: strengthTrendLabel(lead),
            climbingCount: board.climbingCount,
            stalledCount: board.plateauedCount,
            slippingCount: board.slippingCount,
            hasData: !points.isEmpty
        )
    }

    private nonisolated static func strengthTrendLabel(
        _ stat: StrengthOutlookStat
    ) -> String {
        switch stat.trend {
        case .climbing:
            if stat.isFreshPR { return "PR" }
            if let days = stat.daysToPR {
                return days <= 21
                    ? "~\(days)d"
                    : "~\(Int((Double(days) / 7).rounded()))w"
            }
            return "up"
        case .plateaued:
            if let weeks = stat.weeksSinceBest, weeks > 0 {
                return "\(weeks)w flat"
            }
            return "flat"
        case .slipping:
            return "down"
        }
    }

    private nonisolated static func signatureVerdict(
        _ signature: TrainingSignature
    ) -> String {
        "\(signature.identityLine). \(InsightsFormat.perWeekLabel(signature.cadence))x/week all-time average."
    }
}
