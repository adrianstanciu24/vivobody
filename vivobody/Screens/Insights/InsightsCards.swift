//
//  InsightsCards.swift
//  vivobody
//
//  The nine Insights cards in their one reading order. The phone column and
//  the two wide lanes both render this list, so a card added or moved here
//  moves in both compositions.
//

import SwiftUI
import VivoKit

enum InsightsCardID: String, CaseIterable, Identifiable {
    case signature
    case exerciseMix
    case repMix
    case movementCoverage
    case load
    case stamina
    case consistency
    case balance
    case muscleDirectness

    var id: Self {
        self
    }

    /// The lanes alternate by reading order, except that How muscles are
    /// trained joins the trailing lane, whose cards are shorter than the
    /// training signature's lane.
    var wideLane: DashboardLane {
        switch self {
        case .signature, .repMix, .load, .consistency: .leading
        case .exerciseMix, .movementCoverage, .stamina, .balance, .muscleDirectness: .trailing
        }
    }

    /// What sits above a card in the single column.
    enum LeadingSpace: Equatable {
        case none
        case gap(CGFloat)
        case groupSeparator
    }

    /// Separators open each instrument group (Shape's previews, Load,
    /// Rhythm, Balance); gaps keep the cards inside a group together.
    var singleColumnLeadingSpace: LeadingSpace {
        switch self {
        case .signature: .none
        case .exerciseMix, .load, .consistency, .balance: .groupSeparator
        case .repMix: .gap(Space.sm)
        case .movementCoverage: .gap(Space.lg)
        case .stamina, .muscleDirectness: .gap(Space.xl)
        }
    }
}

struct InsightsCard: View {
    let id: InsightsCardID
    let reports: SessionAnalytics.InsightsReports

    var body: some View {
        let core = reports.core
        let deep = reports.deep
        switch id {
        case .signature:
            SignatureSection(
                signature: TrainingSignature(
                    groupVolume: core.groupVolume,
                    cadence: core.overview.averageWorkoutsPerWeek
                )
            )
        case .exerciseMix:
            ExerciseMixLink(board: deep.dominance, split: deep.composition)
        case .repMix:
            RepMixLink(mix: deep.intensity, weeks: deep.intensityWeeks, migration: deep.migration)
        case .movementCoverage:
            MovementCoverageSection(report: deep.movementCoverage)
        case .load:
            TrainingLoadSection(report: core.load)
        case .stamina:
            StaminaSection(report: core.stamina)
        case .consistency:
            ConsistencySection(
                report: deep.consistency,
                allTimeSessionsPerWeek: core.overview.averageWorkoutsPerWeek
            )
        case .balance:
            BalanceInsightsSection(board: deep.symmetry)
        case .muscleDirectness:
            MuscleDirectnessSection(report: deep.muscleDirectness)
        }
    }
}

/// The phone composition: every card in one column.
struct InsightsCardColumn: View {
    let reports: SessionAnalytics.InsightsReports

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(InsightsCardID.allCases) { id in
                switch id.singleColumnLeadingSpace {
                case .none:
                    InsightsCard(id: id, reports: reports)
                case let .gap(space):
                    InsightsCard(id: id, reports: reports)
                        .padding(.top, space)
                case .groupSeparator:
                    GroupSeparator(verticalPadding: Space.section)
                    InsightsCard(id: id, reports: reports)
                }
            }
        }
    }
}
