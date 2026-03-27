import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case cardio
    case stretching
    case other

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue.capitalized
    }
}
