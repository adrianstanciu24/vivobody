import Foundation

struct ExerciseProfileIndex: Decodable {
    let schemaVersion: String
    let method: String
    let exercises: [ExerciseProfileIndexEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case method
        case exercises
    }
}

struct ExerciseProfileIndexEntry: Decodable {
    let id: String
    let displayName: String
    let description: String
    let motionFamily: String
    let isBilateral: Bool
    let apiPath: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case description
        case motionFamily = "motion_family"
        case isBilateral = "bilateral"
        case apiPath = "api_path"
    }
}
