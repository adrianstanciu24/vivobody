//
//  WeightFormatter+Shared.swift
//  vivobody
//
//  Lightweight unit formatting for widget payloads. The app still
//  owns the full WeightUnit metadata; widgets need only canonical-lb
//  conversion and compact display strings.
//

import Foundation

enum WidgetWeightUnit: String, Codable, Hashable {
    case lb, kg

    var symbol: String { rawValue }
    var defaultFractionDigits: Int { self == .lb ? 0 : 1 }
}

enum SharedWeightFormatter {
    static func toDisplay(_ lb: Double, unit: WidgetWeightUnit) -> Double {
        switch unit {
        case .lb: return lb
        case .kg: return lb * 0.45359237
        }
    }

    static func string(
        _ lb: Double,
        unit: WidgetWeightUnit,
        fractionDigits: Int? = nil,
        includeUnit: Bool = true
    ) -> String {
        let display = toDisplay(lb, unit: unit)
        let digits = fractionDigits ?? unit.defaultFractionDigits
        let value = digits == 0 ? "\(Int(display.rounded()))" : String(format: "%.\(digits)f", display)
        return includeUnit ? "\(value) \(unit.symbol)" : value
    }
}
