//
//  TrainNextSection.swift
//  vivobody
//
//  The decision the rest of the muscle data exists to serve: what
//  should I train next? It collapses what used to be three separate
//  per-muscle bar walls (balance, momentum, forecast) into one short
//  ranked list — the top few muscles worth acting on, each with the
//  single most urgent reason and an inline signal that VARIES by that
//  reason (a fade chip, a down arrow, a volume shortfall), so the eye
//  isn't reading yet another row of identical bars.
//
//  The full per-muscle detail still exists — it's one tap away behind
//  "Show all muscles," which pushes the breakdown screen that hosts
//  the original instruments. This section is the glanceable verdict;
//  that screen is the reference.
//

import SwiftUI

struct TrainNextSection: View {
    let plan: TrainNextPlan
    /// Datasets the "Show all muscles" breakdown re-displays in full.
    let stats: [MuscleVolumeStat]
    let momentum: MuscleMomentumBoard
    let forecast: MuscleForecastBoard
    let tightness: MuscleTightnessBoard

    var limit: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Train next", trailing: "priority")

            if !plan.hasItems {
                Text("Nothing logged yet — once you train, the muscles most worth your next session surface here, most urgent first.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                headline

                VStack(spacing: 0) {
                    let shown = plan.top(limit)
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                        row(item)
                        if index < shown.count - 1 {
                            Rectangle()
                                .fill(Surface.edge)
                                .frame(height: 0.5)
                        }
                    }
                }

                showAllLink
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Headline

    /// One plain-language read tuned to the dominant reason among the
    /// top items: urgent when something's slipping, a build cue when
    /// it's just volume, an affirmation when everything's covered.
    @ViewBuilder
    private var headline: some View {
        let shown = plan.top(limit)
        let names = shown.map { InsightsFormat.rowLabel(for: $0.muscle) }

        if shown.contains(where: { isSlipping($0.reason) }) {
            let slipping = shown.filter { isSlipping($0.reason) }.map { InsightsFormat.rowLabel(for: $0.muscle) }
            Text(twoTone(lead: "Losing ground: ", names: slipping, tail: slipping.count == 1 ? " — train it this week to hold your gains." : " — train them this week to hold your gains."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else if shown.contains(where: { if case .underVolume = $0.reason { return true }; return false }) {
            Text(twoTone(lead: "Build more: ", names: names, tail: names.count == 1 ? " is short on volume this week." : " are short on volume this week."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(twoTone(lead: "Well covered — coldest now: ", names: names, tail: "."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func isSlipping(_ reason: TrainNextReason) -> Bool {
        switch reason {
        case .atRisk, .fading: return true
        case .underVolume, .resting: return false
        }
    }

    /// The muscle names brightened against the dimmer surrounding copy
    /// (AttributedString; `Text` `+` is deprecated).
    private func twoTone(lead: String, names: [String], tail: String) -> AttributedString {
        var head = AttributedString(lead); head.foregroundColor = Ink.secondary
        var list = AttributedString(names.joined(separator: ", ")); list.foregroundColor = Ink.primary
        var rest = AttributedString(tail); rest.foregroundColor = Ink.secondary
        return head + list + rest
    }

    // MARK: - Row

    private func row(_ item: TrainNextItem) -> some View {
        HStack(alignment: .center, spacing: Space.md) {
            Circle()
                .fill(color(item.reason))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(InsightsFormat.rowLabel(for: item.muscle))
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text(why(item.reason))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Space.sm)

            signalChip(item.reason)
        }
        .frame(minHeight: 52)
    }

    /// The trailing chip — its text and tint change with the reason,
    /// so each row's "why" reads at a glance without a bar.
    private func signalChip(_ reason: TrainNextReason) -> some View {
        let tint = color(reason)
        return HStack(spacing: 4) {
            Image(systemName: symbol(reason))
                .font(.system(size: 10, weight: .bold))
            Text(chipText(reason))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
    }

    private var showAllLink: some View {
        NavigationLink {
            MuscleDetailScreen(stats: stats, momentum: momentum, forecast: forecast, tightness: tightness)
        } label: {
            HStack(spacing: Space.xs) {
                Text("Show all muscles")
                    .font(Typography.sectionLabel)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Ink.secondary)
        }
        .buttonStyle(.plain)
        .padding(.top, Space.xs)
    }

    // MARK: - Reason → presentation

    private func color(_ reason: TrainNextReason) -> Color {
        switch reason {
        case .atRisk(let days):  return days <= 3 ? Tint.danger : Tint.primary
        case .fading:            return Tint.danger
        case .underVolume:       return Ink.secondary
        case .resting:           return Ink.tertiary
        }
    }

    private func symbol(_ reason: TrainNextReason) -> String {
        switch reason {
        case .atRisk:      return "hourglass"
        case .fading:      return "arrow.down.right"
        case .underVolume: return "plus"
        case .resting:     return "moon.zzz"
        }
    }

    private func chipText(_ reason: TrainNextReason) -> String {
        switch reason {
        case .atRisk(let days):
            return days <= 1 ? "fades 1d" : "fades \(days)d"
        case .fading:
            return "fading"
        case .underVolume(let current, let target):
            let gap = Swift.max(1, Int((target - current).rounded(.up)))
            return "\(gap) sets"
        case .resting(let days):
            guard let days else { return "untrained" }
            if days <= 1 { return "1d rest" }
            return "\(days)d rest"
        }
    }

    private func why(_ reason: TrainNextReason) -> String {
        switch reason {
        case .atRisk:
            return "Development starts slipping within the week if untrained."
        case .fading:
            return "Trending down — train it to turn the curve back up."
        case .underVolume(let current, let target):
            return "\(InsightsFormat.setsLabel(current)) of \(Int(target)) productive sets so far this week."
        case .resting(let days):
            guard let days else { return "Not trained yet — bring it into your week." }
            if days <= 1 { return "Last trained yesterday — still fresh." }
            return "Last trained \(days) days ago."
        }
    }
}
