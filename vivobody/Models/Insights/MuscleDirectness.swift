//
//  MuscleDirectness.swift
//  vivobody
//
//  Splits all-time muscle hard-set equivalents by the role captured when an
//  exercise was logged. Primary work earns full credit; secondary work earns
//  half credit; stabilizers earn none. Examples use current authored primaries.
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
        let sources: [Source]
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

    /// Largest amount of credited secondary work; percentages alone would
    /// overstate a tiny incidental exposure. Stable ties follow muscle identity.
    var passengers: [Row] {
        rows.filter { $0.indirect > 0 }.sorted {
            if $0.indirect != $1.indirect { return $0.indirect > $1.indirect }
            return $0.muscle.rawValue < $1.muscle.rawValue
        }
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
        var sources: [Muscle: [String: MuscleDirectness.Source]] = [:]
        for session in sessions where session.isCompleted && session.date <= now {
            guard !isCancelled() else { break }
            for replay in session.exercises where replay.setEquivalent > 0 {
                for (muscle, role) in replay.exercise.volumeCredits {
                    if role == 1 {
                        direct[muscle, default: 0] += replay.setEquivalent
                    } else if role == 0.5 {
                        let credit = replay.setEquivalent * role
                        indirect[muscle, default: 0] += credit
                        let key = replay.exercise.historyKey
                        var source = sources[muscle]?[key] ?? MuscleDirectness.Source(
                            id: key, name: replay.name, sets: 0
                        )
                        source.sets += credit
                        sources[muscle, default: [:]][key] = source
                    }
                }
            }
        }
        return MuscleDirectness(rows: Muscle.allCases.map { muscle in
            let ranked = Array(sources[muscle, default: [:]].values).sorted {
                $0.sets == $1.sets ? $0.id < $1.id : $0.sets > $1.sets
            }
            return MuscleDirectness.Row(
                muscle: muscle, direct: direct[muscle, default: 0],
                indirect: indirect[muscle, default: 0], sources: ranked,
                examples: MuscleDirectness.examples(for: muscle, catalog: catalog)
            )
        })
    }
}
