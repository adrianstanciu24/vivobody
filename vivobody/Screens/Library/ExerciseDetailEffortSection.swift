//
//  ExerciseDetailEffortSection.swift
//  vivobody
//
//  Focused Exercise Detail effort presentation. It renders one immutable
//  RIR read and progression verdict without querying workout history or
//  reaching into the screen's persistence and navigation state.
//

import SwiftUI
import VivoKit

struct ExerciseDetailEffortSection: View {
    let effort: ExerciseDetailReadModel.Effort?

    var body: some View {
        if let effort {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Effort")
                    .sectionLabelStyle(Opacity.medium)

                HStack(alignment: .center, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(effort.averageText)
                            .font(Typography.statValue)
                            .foregroundStyle(Ink.primary)
                            .monospacedDigit()
                        Text(effort.lastSessionText)
                            .font(Typography.caption)
                            .foregroundStyle(Ink.quaternary)
                    }

                    Spacer(minLength: 8)

                    if let headline = effort.headline {
                        Text(headline)
                            .font(Typography.sectionLabel)
                            .foregroundStyle(verdictColor(effort.verdict))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentCard()
            }
        }
    }

    private func verdictColor(_ verdict: ProgressionVerdict) -> Color {
        switch verdict {
        case .ready: Tint.complete
        case .grind: Tint.danger
        case .push, .none: Ink.tertiary
        }
    }
}
