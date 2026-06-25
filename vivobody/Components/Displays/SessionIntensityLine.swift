//
//  SessionIntensityLine.swift
//  vivobody
//
//  The second support line on the workout "receipt" (live summary +
//  History detail): workout density (tonnage per minute) and the
//  hard-set count (sets taken to RIR ≤ 1). Each half shows only when
//  it has data, and the whole line renders nothing when neither
//  applies — so callers can drop it in unconditionally and gate the
//  surrounding spacing on `hasContent`.
//

import SwiftUI

struct SessionIntensityLine: View {
    let session: WorkoutSession
    let unit: WeightUnit

    /// Whether there's anything to render — lets the caller skip the
    /// leading padding when the line would be empty.
    static func hasContent(_ session: WorkoutSession) -> Bool {
        session.volumeDensity != nil || session.hasLoggedRIR
    }

    var body: some View {
        if let text = Self.text(for: session, unit: unit) {
            Text(text)
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private static func text(for session: WorkoutSession, unit: WeightUnit) -> String? {
        var parts: [String] = []
        if let density = session.volumeDensity {
            let perMin = Int(WeightFormatter.toDisplay(density, unit: unit).rounded())
            parts.append("\(perMin) \(unit.symbol)/min")
        }
        if session.hasLoggedRIR {
            let hard = session.hardSetCount
            parts.append("\(hard) hard \(hard == 1 ? "set" : "sets")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "   ·   ")
    }
}
