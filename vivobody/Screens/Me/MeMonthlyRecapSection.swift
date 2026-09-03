//
//  MeMonthlyRecapSection.swift
//  vivobody
//
//  Current-month recap section rendered from accessibility-ready metrics.
//

import SwiftUI
import VivoKit

struct MeMonthlyRecapSection: View {
    let presentation: MePresentation.Recap

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "This month",
                trailing: presentation.monthLabel
            )
            StatStrip(stats: presentation.metrics.map { metric in
                Stat(
                    value: metric.value,
                    unit: metric.unit,
                    label: metric.label,
                    accessibilityLabel: metric.accessibilityLabel,
                    accent: metric.accent
                )
            })
            .padding(Space.xl)
            .contentCard()
        }
    }
}
