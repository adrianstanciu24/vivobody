import Foundation

enum WorkoutTab: String, CaseIterable {
    case history
    case templates

    var label: String {
        switch self {
        case .history: "HISTORY"
        case .templates: "TEMPLATES"
        }
    }
}
