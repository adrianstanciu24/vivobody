import Foundation

@Observable
final class SettingsViewModel {
    var weightUnit: WeightUnit = .kilograms

    enum WeightUnit: String, CaseIterable, Identifiable {
        case kilograms = "kg"
        case pounds = "lbs"

        var id: String {
            rawValue
        }
    }
}
