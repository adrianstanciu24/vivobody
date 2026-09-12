//
//  MuscleDirectness.swift
//  vivobody
//
//  Splits all-time muscle hard-set equivalents by the role captured when an
//  exercise was logged. Primary work earns full credit; secondary work earns
//  half credit; stabilizers earn one tenth as indirect work. Historical source
//  exercises are retained for both pools; examples use current authored primaries.
//

import Foundation

nonisolated struct MuscleDirectness {
    struct Source: Identifiable {
        let id: String
        let name: String
        var sets: Double
    }

    struct Example: Identifiable {
        let id: String
        let name: String
        let equipment: Equipment
    }

    struct Row: Identifiable {
        let muscle: Muscle
        let direct: Double
        let indirect: Double
        let targetedSources: [Source]
        let supportingSources: [Source]
        let examples: [Example]
        var id: Muscle {
            muscle
        }

        var total: Double {
            direct + indirect
        }

        var indirectShare: Double {
            total > 0 ? indirect / total : 0
        }
    }

    let rows: [Row]
    var trained: [Row] {
        rows.filter { $0.total > 0 }
    }

    /// Intentional work leads the roster by credited targeted volume. Muscles
    /// trained only through supporting roles follow by credited supporting volume.
    /// Stable ties follow muscle identity.
    var targeted: [Row] {
        rows.filter { $0.direct > 0 }.sorted {
            if $0.direct != $1.direct { return $0.direct > $1.direct }
            return $0.muscle.rawValue < $1.muscle.rawValue
        }
    }

    var supportingOnly: [Row] {
        rows.filter { $0.direct == 0 && $0.indirect > 0 }.sorted {
            if $0.indirect != $1.indirect { return $0.indirect > $1.indirect }
            return $0.muscle.rawValue < $1.muscle.rawValue
        }
    }

    var ranked: [Row] {
        targeted + supportingOnly
    }

    static func examples(for muscle: Muscle, catalog: [CatalogRecord]) -> [Example] {
        let eligible = catalog.filter {
            $0.modality.supportsHardSetAnalytics
                && $0.involvement.contains { $0.muscle == muscle && $0.role == .primary }
        }.sorted {
            if $0.searchPriorityValue != $1.searchPriorityValue {
                return $0.searchPriorityValue > $1.searchPriorityValue
            }
            return $0.name < $1.name
        }
        var familyIDs: Set<String> = []
        let varied = eligible.filter { familyIDs.insert($0.familyID).inserted }
        let chosen = Array((varied + eligible.filter { candidate in
            !varied.contains { $0.catalogID == candidate.catalogID }
        }).prefix(3))
        return chosen.map { Example(id: $0.catalogID, name: $0.name, equipment: $0.equipment) }
    }
}

nonisolated extension AnalyticsAccumulator {
    func muscleDirectness(
        catalog: [CatalogRecord] = CatalogData.records,
        now: Date,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> MuscleDirectness {
        var direct: [Muscle: Double] = [:]
        var indirect: [Muscle: Double] = [:]
        var targetedSources: [Muscle: [String: MuscleDirectness.Source]] = [:]
        var supportingSources: [Muscle: [String: MuscleDirectness.Source]] = [:]
        for session in sessions where session.isCompleted && session.date <= now {
            guard !isCancelled() else { break }
            for replay in session.exercises where replay.setEquivalent > 0 {
                for (muscle, role) in replay.exercise.volumeCredits {
                    if role == 1 {
                        direct[muscle, default: 0] += replay.setEquivalent
                        let key = replay.exercise.historyKey
                        var source = targetedSources[muscle]?[key] ?? MuscleDirectness.Source(
                            id: key, name: replay.name, sets: 0
                        )
                        source.sets += replay.setEquivalent
                        targetedSources[muscle, default: [:]][key] = source
                    } else if role > 0, role < 1 {
                        let credit = replay.setEquivalent * role
                        indirect[muscle, default: 0] += credit
                        let key = replay.exercise.historyKey
                        var source = supportingSources[muscle]?[key] ?? MuscleDirectness.Source(
                            id: key, name: replay.name, sets: 0
                        )
                        source.sets += credit
                        supportingSources[muscle, default: [:]][key] = source
                    }
                }
            }
        }
        return MuscleDirectness(rows: Muscle.allCases.map { muscle in
            let targeted = Array(targetedSources[muscle, default: [:]].values).sorted {
                $0.sets == $1.sets ? $0.id < $1.id : $0.sets > $1.sets
            }
            let supporting = Array(supportingSources[muscle, default: [:]].values).sorted {
                $0.sets == $1.sets ? $0.id < $1.id : $0.sets > $1.sets
            }
            return MuscleDirectness.Row(
                muscle: muscle, direct: direct[muscle, default: 0],
                indirect: indirect[muscle, default: 0],
                targetedSources: targeted, supportingSources: supporting,
                examples: MuscleDirectness.examples(for: muscle, catalog: catalog)
            )
        })
    }
}
