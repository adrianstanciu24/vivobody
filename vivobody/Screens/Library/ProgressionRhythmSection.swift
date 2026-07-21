//
//  ProgressionRhythmSection.swift
//  vivobody
//
//  "Progression rhythm" section for ExerciseDetailScreen: the median
//  time between load increases (running-max step-ups from
//  ProgressionCadence), a live "day N of your cycle" read, and a
//  rhythm strip where each tick is a day the lifter added load —
//  spacing proportional to real time, "today" marked at the right
//  edge. Dense ticks read as fast progression; widening gaps read as
//  an approaching plateau.
//
//  Pro-gated with the same frameless frosted treatment as the
//  Insights tab: the real card frozen beneath a blur, tap opens the
//  screen's paywall sheet. Self-gates to nothing for non-comparable
//  work or when history holds fewer than two recorded increases.
//

import VivoKit
import SwiftUI

extension ExerciseDetailScreen {
    /// Cadence over this exercise's chronological progress series.
    /// Nil hides the section entirely (non-comparable work, missing
    /// effective loads, or not enough recorded increases).
    var progressionCadence: ProgressionCadence? {
        guard item.performanceSemanticKind.comparesLoad,
              let prog = progress else { return nil }
        return ProgressionCadence.compute(points: prog.points)
    }

    @ViewBuilder
    var progressionRhythmSection: some View {
        if let cadence = progressionCadence {
            if pro?.isUnlocked == true {
                rhythmSectionContent(cadence)
            } else {
                LockedRhythmCover {
                    Haptics.soft()
                    isPaywallPresented = true
                } content: {
                    rhythmSectionContent(cadence)
                }
            }
        }
    }

    func rhythmSectionContent(_ cadence: ProgressionCadence) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Progression rhythm")
                .sectionLabelStyle(Opacity.medium)
            ProgressionRhythmCard(cadence: cadence)
        }
    }
}

// MARK: - Card

private struct ProgressionRhythmCard: View {
    let cadence: ProgressionCadence

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .firstTextBaseline, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("~\(cadence.medianGapDays)")
                            .font(Typography.statValue)
                            .foregroundStyle(Ink.primary)
                            .monospacedDigit()
                        Text(cadence.medianGapDays == 1 ? "day" : "days")
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                    }
                    Text("between load increases")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }

                Spacer(minLength: Space.sm)

                Text(cycleStatus)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(cadence.isPastUsualRhythm ? Tint.complete : Ink.tertiary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                RhythmStrip(
                    events: cadence.events,
                    isPastUsualRhythm: cadence.isPastUsualRhythm
                )
                Text("Each tick is a load increase · the dot is today")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Surface.cardTint)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// Right-aligned read connecting the median to today. "Day N of
    /// ~M" while inside the usual window; a quiet "due" nudge once
    /// the current gap outruns the rhythm.
    private var cycleStatus: String {
        if cadence.daysSinceLastIncrease == 0 {
            return "Increased today"
        }
        if cadence.isPastUsualRhythm {
            return "Day \(cadence.daysSinceLastIncrease) · past your usual rhythm"
        }
        return "Day \(cadence.daysSinceLastIncrease) of ~\(cadence.medianGapDays)"
    }

    private var accessibilitySummary: String {
        let unit = cadence.medianGapDays == 1 ? "day" : "days"
        return "Progression rhythm. You typically add load every \(cadence.medianGapDays) \(unit). \(cycleStatus)."
    }
}

// MARK: - Rhythm strip

/// Thin proportional timeline: a dim tick for the baseline session,
/// a bright tick per load increase, and a dot for today at the right
/// edge. Long histories keep only the most recent events so ticks
/// stay legible.
private struct RhythmStrip: View {
    let events: [ProgressionCadence.Event]
    let isPastUsualRhythm: Bool

    var now: Date = Date()

    /// Most-recent events kept on the strip. Older history compresses
    /// into nothing rather than crowding the left edge.
    private static let maxTicks = 7

    private var visibleEvents: [ProgressionCadence.Event] {
        Array(events.suffix(Self.maxTicks))
    }

    /// The leading tick is the true starting level only when nothing
    /// was trimmed; a trimmed strip starts on an increase.
    private var firstVisibleIsBaseline: Bool {
        events.count <= Self.maxTicks
    }

    var body: some View {
        let visible = visibleEvents
        let start = visible.first?.date ?? now
        let span = max(now.timeIntervalSince(start), 1)

        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Surface.edge)
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)

                ForEach(Array(visible.enumerated()), id: \.offset) { index, event in
                    let fraction = min(max(event.date.timeIntervalSince(start) / span, 0), 1)
                    Capsule()
                        .fill(tickColor(index: index))
                        .frame(width: 3, height: 16)
                        .offset(x: fraction * (width - 3))
                }

                Circle()
                    .fill(isPastUsualRhythm ? Tint.complete : Ink.tertiary)
                    .frame(width: 6, height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .offset(x: width - 6)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    private func tickColor(index: Int) -> Color {
        index == 0 && firstVisibleIsBaseline
            ? Ink.tertiary
            : Ink.primary.opacity(Opacity.strong)
    }
}

// MARK: - Locked cover

/// Same frameless frosted treatment as the Insights tab's locked
/// sections: the real content frozen beneath a blur, the whole area
/// one button that opens the paywall. Accessibility sees only the
/// locked section, never the numbers beneath it.
private struct LockedRhythmCover<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        Button(action: action) {
            content()
                .blur(radius: reduceTransparency ? 0 : 8)
                .opacity(reduceTransparency ? 0 : 0.90)
                .accessibilityHidden(true)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Progression rhythm, locked")
        .accessibilityHint("Unlocks with Vivobody Pro")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Progression rhythm") {
    let day: TimeInterval = 86_400
    let now = Date()
    let cadence = ProgressionCadence(
        baseline: .init(date: now.addingTimeInterval(-64 * day), load: 135),
        increases: [
            .init(date: now.addingTimeInterval(-55 * day), load: 140),
            .init(date: now.addingTimeInterval(-46 * day), load: 145),
            .init(date: now.addingTimeInterval(-34 * day), load: 150),
            .init(date: now.addingTimeInterval(-27 * day), load: 155),
            .init(date: now.addingTimeInterval(-13 * day), load: 160),
        ],
        medianGapDays: 9,
        daysSinceLastIncrease: 13
    )
    return VStack(spacing: Space.xxl) {
        ProgressionRhythmCard(cadence: cadence)
        LockedRhythmCover(action: {}) {
            ProgressionRhythmCard(cadence: cadence)
        }
    }
    .padding(Space.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
#endif
