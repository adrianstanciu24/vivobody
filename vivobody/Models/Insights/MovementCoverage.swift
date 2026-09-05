//
//  MovementCoverage.swift
//  vivobody
//
//  All-time hard-set allocation across anatomical planes. Each exercise
//  contributes once, divided equally across its unique snapshotted planes.
//  Family actions describe recorded coverage, not a prescription or a score.
//

import Foundation

nonisolated struct MovementCoverage {
    struct ActionGap: Identifiable {
        let action: CatalogMovementAction
        let families: [CatalogMovementFamily]
        var id: String {
            action.id
        }
    }

    let setsByPlane: [MovementPlane: Double]
    let unclassifiedSets: Double
    let unknownActionSets: Double
    let missingActions: [ActionGap]
    let families: [CatalogMovementFamily]

    var classifiedSets: Double {
        setsByPlane.values.reduce(0, +)
    }

    var totalSets: Double {
        classifiedSets + unclassifiedSets
    }

    var hasData: Bool {
        classifiedSets > 0
    }

    var missingPlanes: [MovementPlane] {
        MovementPlane.allCases.filter { setsByPlane[$0, default: 0] == 0 }
    }

    func share(_ plane: MovementPlane) -> Double {
        classifiedSets > 0 ? setsByPlane[plane, default: 0] / classifiedSets : 0
    }

    /// Largest-remainder rounding keeps the three visible percentages at 100.
    func percentage(_ plane: MovementPlane) -> Int {
        guard hasData else { return 0 }
        let planes = MovementPlane.allCases
        var result = planes.map { Int((share($0) * 100).rounded(.down)) }
        let ordered = planes.indices.sorted {
            let left = share(planes[$0]) * 100 - Double(result[$0])
            let right = share(planes[$1]) * 100 - Double(result[$1])
            return left == right ? $0 < $1 : left > right
        }
        for index in ordered.prefix(max(0, 100 - result.reduce(0, +))) {
            result[index] += 1
        }
        return result[planes.firstIndex(of: plane) ?? 0]
    }

    func families(for plane: MovementPlane) -> [CatalogMovementFamily] {
        families.filter { $0.planes.contains(plane) }
    }
}

nonisolated extension AnalyticsAccumulator {
    func movementCoverage(
        families: [CatalogMovementFamily] = CatalogMovementFamily.bundled,
        now: Date,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> MovementCoverage {
        let byID = Dictionary(uniqueKeysWithValues: families.map { ($0.id, $0) })
        var planes: [MovementPlane: Double] = [:]
        var unknownPlanes = 0.0
        var unknownActions = 0.0
        var touchedActions: Set<String> = []
        for session in sessions where session.isCompleted && session.date <= now {
            guard !isCancelled() else { break }
            for replay in session.exercises where replay.setEquivalent > 0 {
                let authored = Set(replay.classification?.planes ?? [])
                if authored.isEmpty {
                    unknownPlanes += replay.setEquivalent
                } else {
                    for plane in authored {
                        planes[plane, default: 0] += replay.setEquivalent / Double(authored.count)
                    }
                }
                if let id = replay.exercise.familyID, let family = byID[id] {
                    touchedActions.formUnion(family.actions.map(\.id))
                } else {
                    unknownActions += replay.setEquivalent
                }
            }
        }
        let actions = Set(families.flatMap(\.actions))
        let gaps = actions.filter { !touchedActions.contains($0.id) }.map { action in
            MovementCoverage.ActionGap(
                action: action,
                families: families.filter { $0.actions.contains(action) }
            )
        }.sorted { $0.action.displayName < $1.action.displayName }
        return MovementCoverage(
            setsByPlane: planes, unclassifiedSets: unknownPlanes,
            unknownActionSets: unknownActions, missingActions: gaps, families: families
        )
    }
}
