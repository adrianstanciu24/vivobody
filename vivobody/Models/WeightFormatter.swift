//
//  WeightFormatter.swift
//  vivobody
//
//  Central conversion + display formatting for canonical-lb weight
//  values. Every display site and every scrubber binding routes
//  through here so units of measure stay consistent across the app.
//
//  Conventions:
//    • Storage value (input to `string`, `toDisplay`) is ALWAYS in lb.
//    • Display value (input to `toCanonical`, output of `toDisplay`)
//      is in the user's selected unit.
//    • Helpers take `WeightUnit` explicitly — the formatter is a
//      pure utility with no SwiftUI / UserDefaults dependency, so
//      it can be tested and reused outside view code.
//

import Foundation

enum WeightFormatter {

    // MARK: - Numeric conversion

    /// Convert a canonical pounds value to a value in the user's
    /// preferred unit, suitable for showing in a scrubber or label.
    static func toDisplay(_ lb: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .lb: return lb
        case .kg: return lb * WeightUnit.kgPerLb
        }
    }

    /// Convert a display-unit value (the user typed / scrubbed it
    /// in their unit) back to canonical lb for storage.
    static func toCanonical(_ display: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .lb: return display
        case .kg: return display * WeightUnit.lbPerKg
        }
    }

    // MARK: - Convenience: convert a closed range

    /// Same conversion applied to a closed range (used by the scrubber
    /// wrapper to translate a canonical-lb range into display-unit
    /// bounds for its underlying NumberScrubber).
    static func toDisplay(_ range: ClosedRange<Double>, unit: WeightUnit) -> ClosedRange<Double> {
        toDisplay(range.lowerBound, unit: unit) ... toDisplay(range.upperBound, unit: unit)
    }

    // MARK: - String formatting

    /// Format a canonical lb value as a display string like
    /// "135 lb" or "61.2 kg". Pass `fractionDigits` to override
    /// the unit's default precision (e.g. body weight should always
    /// show 1 fraction digit regardless of unit).
    static func string(
        _ lb: Double,
        unit: WeightUnit,
        fractionDigits: Int? = nil,
        includeUnit: Bool = true
    ) -> String {
        let display = toDisplay(lb, unit: unit)
        let digits = fractionDigits ?? unit.defaultFractionDigits
        let valueString = formatValue(display, digits: digits)
        return includeUnit ? "\(valueString) \(unit.symbol)" : valueString
    }

    /// Format a delta value (still in canonical lb) with an explicit
    /// sign prefix. Positive values get "+", negatives get "−" via
    /// the negative number's natural minus.
    static func deltaString(
        _ lb: Double,
        unit: WeightUnit,
        fractionDigits: Int? = nil,
        includeUnit: Bool = true
    ) -> String {
        let display = toDisplay(lb, unit: unit)
        let digits = fractionDigits ?? unit.defaultFractionDigits
        let sign = display > 0 ? "+" : ""
        let valueString = "\(sign)\(formatValue(display, digits: digits))"
        return includeUnit ? "\(valueString) \(unit.symbol)" : valueString
    }

    /// Format a large total (e.g. session / lifetime volume) with
    /// thousands-separated grouping for clarity. Beyond 10,000 the
    /// value is compacted to "Xk" form so it never wraps in stat
    /// cards. Always whole numbers — volume's precision past the
    /// 1-unit mark is noise.
    static func volumeString(_ lb: Double, unit: WeightUnit) -> String {
        let display = toDisplay(lb, unit: unit)
        if display >= 10_000 {
            let k = display / 1000
            let compact = k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
            return "\(compact) \(unit.symbol)"
        }
        let valueString = volumeFormatter.string(from: NSNumber(value: Int(display)))
            ?? "\(Int(display))"
        return "\(valueString) \(unit.symbol)"
    }

    /// Volume value alone (no unit suffix) — for cards that already
    /// render the unit as a separate label.
    static func volumeValue(_ lb: Double, unit: WeightUnit) -> String {
        let display = toDisplay(lb, unit: unit)
        if display >= 10_000 {
            let k = display / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return volumeFormatter.string(from: NSNumber(value: Int(display)))
            ?? "\(Int(display))"
    }

    // MARK: - Internals

    private static func formatValue(_ value: Double, digits: Int) -> String {
        if digits == 0 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.\(digits)f", value)
    }

    private static let volumeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()
}
