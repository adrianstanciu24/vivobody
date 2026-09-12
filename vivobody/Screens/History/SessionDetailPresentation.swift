//
//  SessionDetailPresentation.swift
//  vivobody
//
//  One bounded presentation snapshot for an archived workout receipt. It
//  resolves relationship order, standout sets, row totals, superset tags,
//  adherence, contributions, and the current load trace once per render.
//

import Foundation

@MainActor
struct SessionDetailPresentation {
    struct ExerciseRow {
        let exercise: Exercise
        let orderedSets: [WorkoutSet]
        let topSetID: UUID?
        let receiptTonnage: Double
        let completedReps: Int
        let completedDuration: TimeInterval
        let contribution: SessionContribution?
        let adherence: ExerciseAdherence?
        let supersetTag: String?
    }

    let receiptMetric: WorkoutReceiptMetric
    let currentLoadTrace: WorkoutLoadTrace
    let exerciseRows: [ExerciseRow]
    let workoutTitle: String
    let dateLine: String
    let durationMinutes: Int
    let totalSets: Int
    let totalReps: Int
    let topSetValue: String

    var exercisesSubtitle: String {
        exerciseRows.count == 1
            ? "1 exercise"
            : "\(exerciseRows.count) exercises"
    }

    init(session: WorkoutSession, unit: WeightUnit) {
        let orderedExercises = session.orderedExercises
        let contributions = session.receiptContributions(
            in: orderedExercises
        )
        let supersetTags = SupersetGrouping.tags(
            inIDs: orderedExercises.map(\.supersetID)
        )

        var rows: [ExerciseRow] = []
        rows.reserveCapacity(orderedExercises.count)
        var setCount = 0
        var repCount = 0
        var comparableSetLoads: [Double] = []
        var hasMissingComparableLoad = false

        for (index, exercise) in orderedExercises.enumerated() {
            let sets = exercise.orderedSets
            let topSet = exercise.representativeTopSet
            let completedReps = exercise.trackingMode == .reps
                ? sets.reduce(0) { $0 + ($1.isCompleted ? $1.reps : 0) }
                : 0
            let completedDuration = exercise.trackingMode == .duration
                ? sets.reduce(0) { $0 + ($1.isCompleted ? $1.duration : 0) }
                : 0
            setCount += sets.count(where: \.isCompleted)
            repCount += completedReps
            if exercise.modality.supportsComparableTonnage(
                for: exercise.trackingMode,
                loadMode: exercise.loadMode
            ) {
                for set in sets where set.isAnalyticsEligible && set.reps > 0 {
                    guard let load = exercise.effectiveLoad(
                        loggedWeight: set.weight
                    ) else {
                        hasMissingComparableLoad = true
                        continue
                    }
                    comparableSetLoads.append(max(0, load) * Double(set.reps))
                }
            }
            rows.append(ExerciseRow(
                exercise: exercise,
                orderedSets: sets,
                topSetID: topSet?.id,
                receiptTonnage: exercise.completedReceiptTonnage ?? 0,
                completedReps: completedReps,
                completedDuration: completedDuration,
                contribution: contributions[exercise.id],
                adherence: session.adherence(
                    for: exercise,
                    topSet: topSet,
                    orderedSets: sets
                ),
                supersetTag: supersetTags[index]
            ))
        }

        let muscleTags = Self.distinctMuscleGroups(in: orderedExercises)
        workoutTitle = switch muscleTags.count {
        case 0: "Workout"
        case 1: "\(muscleTags[0].displayName) day"
        case 2: "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: "Full body"
        }
        let date = session.completedAt ?? session.startedAt
        dateLine = SessionDetailPresentation.dateFormatter.string(from: date)
        durationMinutes = max(0, Int(session.duration / 60))
        totalSets = setCount
        totalReps = repCount
        exerciseRows = rows
        receiptMetric = session.primaryReceiptMetric(unit: unit)
        let loadAvailability: ComparableTonnageAvailability = if hasMissingComparableLoad {
            comparableSetLoads.isEmpty ? .unavailable : .partial
        } else {
            .complete
        }
        currentLoadTrace = WorkoutLoadTrace(
            setLoads: comparableSetLoads,
            availability: loadAvailability
        )
        topSetValue = Self.topSetValue(rows: rows, unit: unit)
    }

    private static func distinctMuscleGroups(
        in exercises: [Exercise]
    ) -> [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var result: [MuscleGroup] = []
        for exercise in exercises where seen.insert(exercise.group).inserted {
            result.append(exercise.group)
        }
        return result
    }

    private static func topSetValue(
        rows: [ExerciseRow],
        unit: WeightUnit
    ) -> String {
        var loadedBest: (Exercise, WorkoutSet, Double)?
        var unloadedBest: (Exercise, WorkoutSet)?

        for row in rows where row.exercise.trackingMode == .reps {
            let exercise = row.exercise
            for set in row.orderedSets where set.isAnalyticsEligible {
                if exercise.performanceSemanticKind.comparesLoad,
                   let load = exercise.effectiveLoad(loggedWeight: set.weight)
                {
                    if let standing = loadedBest {
                        if load > standing.2
                            || (load == standing.2 && set.reps > standing.1.reps)
                        {
                            loadedBest = (exercise, set, load)
                        }
                    } else {
                        loadedBest = (exercise, set, load)
                    }
                } else if !exercise.tracksResistance, set.reps > 0,
                          unloadedBest.map({ set.reps > $0.1.reps }) ?? true
                {
                    unloadedBest = (exercise, set)
                }
            }
        }

        if let (exercise, set, _) = loadedBest {
            return exercise.setLabel(set, unit: unit)
        }
        if let (exercise, set) = unloadedBest {
            return exercise.setLabel(set, unit: unit)
        }
        return "—"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE  ·  MMM d  ·  h:mm a"
        return formatter
    }()
}
