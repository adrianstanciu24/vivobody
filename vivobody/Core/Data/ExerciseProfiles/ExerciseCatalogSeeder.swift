import SwiftData

@MainActor
struct ExerciseCatalogSeeder {
    private let catalogItems: [ExerciseCatalogItem]

    init(store: BundledExerciseProfileStore) throws {
        catalogItems = try store.loadCatalog()
    }

    init(catalogItems: [ExerciseCatalogItem]) {
        self.catalogItems = catalogItems
    }

    func sync(modelContext: ModelContext) throws {
        let catalogByID = Dictionary(uniqueKeysWithValues: catalogItems.map { ($0.id, $0) })
        let catalogByName = Dictionary(uniqueKeysWithValues: catalogItems.map { ($0.displayName.lowercased(), $0) })

        try backfillWorkoutSnapshots(in: modelContext)
        try syncExercises(in: modelContext, catalogByID: catalogByID, catalogByName: catalogByName)
        try syncTemplateExercises(in: modelContext, catalogByID: catalogByID, catalogByName: catalogByName)

        try modelContext.save()
    }

    private func syncExercises(
        in modelContext: ModelContext,
        catalogByID: [String: ExerciseCatalogItem],
        catalogByName: [String: ExerciseCatalogItem]
    ) throws {
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        var existingCatalogIDs = Set<String>()

        for exercise in exercises {
            if let item = matchedCatalogItem(
                catalogID: exercise.catalogID,
                name: exercise.name,
                catalogByID: catalogByID,
                catalogByName: catalogByName
            ) {
                apply(item, to: exercise)
                existingCatalogIDs.insert(item.id)
            } else {
                try backfillSnapshots(referencing: exercise, in: modelContext)
                modelContext.delete(exercise)
            }
        }

        for item in catalogItems where !existingCatalogIDs.contains(item.id) {
            modelContext.insert(makeExercise(from: item))
        }
    }

    private func syncTemplateExercises(
        in modelContext: ModelContext,
        catalogByID: [String: ExerciseCatalogItem],
        catalogByName: [String: ExerciseCatalogItem]
    ) throws {
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        let exerciseByCatalogID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.catalogID, $0) })
        let templateExercises = try modelContext.fetch(FetchDescriptor<TemplateExercise>())

        for templateExercise in templateExercises {
            if let item = matchedCatalogItem(
                catalogID: templateExercise.catalogID,
                name: templateExercise.name,
                catalogByID: catalogByID,
                catalogByName: catalogByName
            ) {
                templateExercise.catalogID = item.id
                templateExercise.name = item.displayName
                templateExercise.primaryTag = item.primaryTag
                templateExercise.secondaryTags = item.secondaryTags
                templateExercise.exercise = exerciseByCatalogID[item.id]
            } else {
                modelContext.delete(templateExercise)
            }
        }
    }

    private func backfillWorkoutSnapshots(in modelContext: ModelContext) throws {
        let workoutExercises = try modelContext.fetch(FetchDescriptor<WorkoutExercise>())

        for workoutExercise in workoutExercises {
            guard let exercise = workoutExercise.exercise else { continue }

            if workoutExercise.exerciseCatalogIDSnapshot.isEmpty {
                workoutExercise.exerciseCatalogIDSnapshot = exercise.catalogID
            }
            if workoutExercise.exerciseNameSnapshot.isEmpty {
                workoutExercise.exerciseNameSnapshot = exercise.name
            }
            if workoutExercise.exercisePrimaryTagSnapshot.isEmpty {
                workoutExercise.exercisePrimaryTagSnapshot = exercise.primaryTag
            }
            if workoutExercise.exerciseSecondaryTagsSnapshot.isEmpty {
                workoutExercise.exerciseSecondaryTagsSnapshot = exercise.secondaryTags
            }
            if workoutExercise.exerciseMuscleGroupSnapshot.isEmpty {
                workoutExercise.exerciseMuscleGroupSnapshot = exercise.muscleGroup.displayName
            }
        }
    }

    private func backfillSnapshots(
        referencing exercise: Exercise,
        in modelContext: ModelContext
    ) throws {
        let workoutExercises = try modelContext.fetch(FetchDescriptor<WorkoutExercise>())

        for workoutExercise in workoutExercises {
            guard workoutExercise.exercise?.persistentModelID == exercise.persistentModelID else {
                continue
            }

            if workoutExercise.exerciseCatalogIDSnapshot.isEmpty {
                workoutExercise.exerciseCatalogIDSnapshot = exercise.catalogID
            }
            if workoutExercise.exerciseNameSnapshot.isEmpty {
                workoutExercise.exerciseNameSnapshot = exercise.name
            }
            if workoutExercise.exercisePrimaryTagSnapshot.isEmpty {
                workoutExercise.exercisePrimaryTagSnapshot = exercise.primaryTag
            }
            if workoutExercise.exerciseSecondaryTagsSnapshot.isEmpty {
                workoutExercise.exerciseSecondaryTagsSnapshot = exercise.secondaryTags
            }
            if workoutExercise.exerciseMuscleGroupSnapshot.isEmpty {
                workoutExercise.exerciseMuscleGroupSnapshot = exercise.muscleGroup.displayName
            }
        }
    }

    private func matchedCatalogItem(
        catalogID: String,
        name: String,
        catalogByID: [String: ExerciseCatalogItem],
        catalogByName: [String: ExerciseCatalogItem]
    ) -> ExerciseCatalogItem? {
        if !catalogID.isEmpty, let item = catalogByID[catalogID] {
            return item
        }

        return catalogByName[name.lowercased()]
    }

    private func apply(_ item: ExerciseCatalogItem, to exercise: Exercise) {
        exercise.catalogID = item.id
        exercise.name = item.displayName
        exercise.muscleGroup = item.muscleGroup
        exercise.category = item.category
        exercise.primaryTag = item.primaryTag
        exercise.secondaryTags = item.secondaryTags
        exercise.motionFamily = item.motionFamily
        exercise.isBilateral = item.isBilateral
    }

    private func makeExercise(from item: ExerciseCatalogItem) -> Exercise {
        Exercise(
            catalogID: item.id,
            name: item.displayName,
            muscleGroup: item.muscleGroup,
            category: item.category,
            primaryTag: item.primaryTag,
            secondaryTags: item.secondaryTags,
            motionFamily: item.motionFamily,
            isBilateral: item.isBilateral
        )
    }
}
