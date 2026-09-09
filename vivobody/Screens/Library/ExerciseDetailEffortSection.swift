//
//  ExerciseDetailEffortSection.swift
//  vivobody
//
//  Focused Exercise Detail effort presentation. It renders one immutable
//  RIR read without querying workout history or
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
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentCard()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(effort.accessibilityLabel)
            }
        }
    }
}
