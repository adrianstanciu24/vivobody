//
//  ExerciseHeroHeader.swift
//  vivobody
//
//  The exercise detail screen's hero: an orange modality eyebrow
//  over the exercise name, plus a plateau / load-mode-aware
//  readiness status pill. The eyebrow uses the same accent kicker
//  treatment as the Insights hero's identity line, and sits above
//  the title so it never stacks against the also-orange readiness
//  pill below. The builders live in their own file for the same
//  reason `movementSection` lives beside its card — to keep the
//  oversized sections file under its ratchet.
//

import SwiftUI
import VivoKit

extension ExerciseDetailScreen {
    // MARK: - Hero

    var hero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(item.modality.displayName.uppercased())
                .font(Typography.metricUnit)
                .foregroundStyle(Tint.primary)
                .tracking(1.4)

            Text(item.name)
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
    var readinessAction: String? {
        effortSummary?.verdict.progressionAction(for: item.loadMode)
    }

    /// Plateau wins over readiness when both could fire — a stall is
    /// the more urgent signal. Renders nothing when neither applies.
    @ViewBuilder
    var statusPill: some View {
        if !supportsEstimatedOneRepMax, let plateau = plateauStatus {
            pill(text: "Stalled · \(plateau.sessions) sessions", accent: false)
        } else if let readinessAction {
            pill(text: "Ready to \(readinessAction)", accent: true)
        }
    }

    func pill(text: String, accent: Bool) -> some View {
        Text(text)
            .font(Typography.metricUnit)
            .foregroundStyle(accent ? Tint.complete : Ink.tertiary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(Capsule().fill(Surface.cardTint))
            .overlay(Capsule().stroke(accent ? Tint.primaryDim : Surface.edge, lineWidth: 1))
    }
}
