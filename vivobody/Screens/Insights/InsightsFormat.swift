//
//  InsightsFormat.swift
//  vivobody
//
//  The small vocabulary the Insights sections share: row labels,
//  set/frequency number formatting, and the one monospaced stat font
//  the strips line up on. Each section component owns its own colours
//  and copy; only the genuinely cross-section helpers live here so the
//  sections stay independent without copy-pasting these few pieces.
//

import SwiftUI

enum InsightsFormat {
    /// Row label for a muscle. Two regions share their name with their
    /// body-part group ("Chest", "Shoulders"); sitting directly under
    /// that group header they'd read as a duplicate, so they fall back
    /// to their anatomical name here.
    static func rowLabel(for muscle: Muscle) -> String {
        switch muscle {
        case .pectorals: return "Pectorals"
        case .deltoids:  return "Deltoids"
        default:         return muscle.displayName
        }
    }

    /// One decimal place for an effective-set count, with a clean "0"
    /// for an untrained muscle.
    static func setsLabel(_ value: Double) -> String {
        value <= 0 ? "0" : String(format: "%.1f", value)
    }

    /// Sessions-per-week to one decimal.
    static func perWeekLabel(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// The monospaced face every Insights `StatStrip` value uses, so
    /// the big numbers never jitter and read as one family.
    static let monoStat = Font.system(size: 22, weight: .bold, design: .monospaced)
}
