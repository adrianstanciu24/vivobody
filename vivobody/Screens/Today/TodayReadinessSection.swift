//
//  TodayReadinessSection.swift
//  vivobody
//
//  Binding-free Training Load drill-out surface for Today.
//

import SwiftUI
import VivoKit

struct TodayReadinessSection: View {
    let report: TrainingLoadReport
    let line: ReadinessLine
    let onShowDetails: () -> Void

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    var body: some View {
        Button {
            Haptics.selection()
            onShowDetails()
        } label: {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(
                    title: "Training Load",
                    trailing: ReadinessCard.scopeText
                )
                ReadinessCard(report: report, line: line)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Training load")
        .accessibilityValue(ReadinessCard.accessibilityValue(for: report, line: line, unit: unit))
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        switch report.measure {
        case .volumeLoad:
            "Opens an explanation of your seven-day volume load and personal range"
        case .hardSets:
            "Opens an explanation of your seven-day load and personal range"
        }
    }
}
