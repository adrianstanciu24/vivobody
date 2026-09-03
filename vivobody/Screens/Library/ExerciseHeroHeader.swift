//
//  ExerciseHeroHeader.swift
//  vivobody
//
//  Stateless exercise-detail hero presentation: an orange modality
//  eyebrow over the exercise name, plus an optional plateau or
//  load-mode-aware readiness status. Archive derivation stays outside
//  this leaf view.
//

import SwiftUI
import VivoKit

struct ExerciseHeroHeader: View {
    let name: String
    let modality: ExerciseModality
    let supportsEstimatedOneRepMax: Bool
    let plateauStatus: PlateauStatus?
    let readinessAction: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(modality.displayName.uppercased())
                .font(Typography.metricUnit)
                .foregroundStyle(Tint.primary)
                .tracking(1.4)

            Text(name)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            if hasStatusPill {
                statusPill
            }
        }
    }

    /// True when the hero has a plateau or readiness pill to show.
    /// Comparable dynamic lifts leave direction to the e1RM trend card,
    /// avoiding a raw-record "stalled" pill that could contradict it.
    var hasStatusPill: Bool {
        (!supportsEstimatedOneRepMax && plateauStatus != nil)
            || readinessAction != nil
    }

    /// Resistance progression follows the exercise's load polarity.
    /// Machine-assisted work advances by reducing assistance.
    /// Plateau wins over readiness when both could fire — a stall is
    /// the more urgent signal. Renders nothing when neither applies.
    @ViewBuilder
    private var statusPill: some View {
        if !supportsEstimatedOneRepMax, let plateau = plateauStatus {
            pill(text: "Stalled · \(plateau.sessions) sessions", accent: false)
        } else if let readinessAction {
            pill(text: "Ready to \(readinessAction)", accent: true)
        }
    }

    private func pill(text: String, accent: Bool) -> some View {
        Text(text)
            .font(Typography.metricUnit)
            .foregroundStyle(accent ? Tint.complete : Ink.tertiary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(Capsule().fill(Surface.cardTint))
            .overlay(Capsule().stroke(accent ? Tint.primaryDim : Surface.edge, lineWidth: 1))
    }
}

#if DEBUG
    #Preview("Exercise hero") {
        ExerciseHeroHeader(
            name: "Barbell Bench Press",
            modality: .dynamicStrength,
            supportsEstimatedOneRepMax: true,
            plateauStatus: nil,
            readinessAction: "add load"
        )
        .padding(Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
