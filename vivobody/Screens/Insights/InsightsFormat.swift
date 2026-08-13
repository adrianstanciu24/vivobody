//
//  InsightsFormat.swift
//  vivobody
//
//  The small number-formatting vocabulary the Insights sections share.
//  Each section component owns its own colours and copy; only the
//  genuinely cross-section helpers live here so the sections stay
//  independent without copy-pasting these few pieces.
//

import SwiftUI

enum InsightsFormat {
    /// One decimal place for an effective-set count, with a clean "0"
    /// for an untrained muscle.
    static func setsLabel(_ value: Double) -> String {
        value <= 0 ? "0" : String(format: "%.1f", value)
    }

    /// Sessions per week, dropping a redundant decimal when the
    /// one-decimal value is a whole number.
    nonisolated static func perWeekLabel(_ value: Double) -> String {
        let oneDecimal = (value * 10).rounded() / 10
        if oneDecimal == oneDecimal.rounded() {
            return String(format: "%.0f", oneDecimal)
        }
        return String(format: "%.1f", oneDecimal)
    }
}
