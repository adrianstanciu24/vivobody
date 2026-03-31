import Foundation
import SwiftData

struct TemplateDraft {
    let name: String
    let selectedMuscles: Set<String>
    let scheduleDays: Set<Int>
    let notes: String
    let exercises: [TemplateExerciseItem]
}

@Observable
final class CreateTemplateViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(existingTemplate: WorkoutTemplate?, draft: TemplateDraft) {
        let muscleGroups = Array(Set(draft.selectedMuscles.compactMap { Self.muscleGroup(from: $0) }))

        let template: WorkoutTemplate
        if let existingTemplate {
            template = existingTemplate
            template.name = draft.name
            template.muscleGroups = muscleGroups
            template.scheduleDays = Array(draft.scheduleDays).sorted()
            template.notes = draft.notes
            for exercise in template.exercises {
                modelContext.delete(exercise)
            }
            template.exercises.removeAll()
        } else {
            template = WorkoutTemplate(
                name: draft.name,
                muscleGroups: muscleGroups,
                scheduleDays: Array(draft.scheduleDays).sorted(),
                notes: draft.notes
            )
            modelContext.insert(template)
        }

        for (index, item) in draft.exercises.enumerated() {
            let parts = item.restLabel.split(separator: ":")
            let restSeconds = parts.count == 2
                ? (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0)
                : 60

            let catalogID = item.catalogID
            let exerciseDescriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.catalogID == catalogID }
            )
            let exercise = try? modelContext.fetch(exerciseDescriptor).first

            let templateExercise = TemplateExercise(
                order: index,
                catalogID: item.catalogID,
                targetSets: item.sets,
                targetReps: item.targetReps,
                restSeconds: restSeconds,
                name: item.name,
                primaryTag: item.primaryTag,
                secondaryTags: item.secondaryTags,
                template: template,
                exercise: exercise
            )
            template.exercises.append(templateExercise)
        }
    }

    static func muscleGroup(from name: String) -> MuscleGroup? {
        switch name {
        case "CHEST": .chest
        case "BACK": .back
        case "SHOULDERS": .shoulders
        case "BICEPS": .biceps
        case "TRICEPS": .triceps
        case "QUADS", "HAMSTRINGS", "GLUTES", "CALVES": .legs
        case "CORE": .core
        default: nil
        }
    }
}
