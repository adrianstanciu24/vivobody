import Foundation

struct ExerciseProfile: Decodable {
    let exercise: ExerciseProfileExercise
    let targets: ExerciseProfileTargets
}

struct ExerciseProfileExercise: Decodable {
    let id: String
    let displayName: String
    let description: String
    let motionFamily: String
    let isBilateral: Bool
    let movementTags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case description
        case motionFamily = "motion_family"
        case isBilateral = "bilateral"
        case movementTags = "movement_tags"
    }
}

struct ExerciseProfileTargets: Decodable {
    let primary: [ExerciseProfileTarget]
    let all: [ExerciseProfileTarget]
}

struct ExerciseProfileTarget: Decodable {
    let id: String
    let label: String
    let share: Double
}

struct ExerciseCatalogItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let description: String
    let motionFamily: String
    let isBilateral: Bool
    let apiPath: String
    let muscleGroup: MuscleGroup
    let category: ExerciseCategory
    let primaryTag: String
    let secondaryTags: String

    var tags: String {
        guard !secondaryTags.isEmpty else { return primaryTag }
        guard !primaryTag.isEmpty else { return secondaryTags }
        return "\(primaryTag) · \(secondaryTags)"
    }
}
