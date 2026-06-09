//
//  MobilitySection.swift
//  vivobody
//
//  The lengthening counterpart to Muscle Balance, inside the
//  all-muscles breakdown: which muscles have tightened from
//  contraction-biased loading and owe some mobility. It reads the same
//  tightness channel of `MuscleDevelopment` that draws the cool strain
//  rim on the Today figure, so the roster here names exactly the
//  muscles the body is rimming — and what to stretch to clear them.
//
//  Tightness is luminance-coded like everything else (no second hue);
//  the cool reading lives only on the 3D body, referenced here in
//  words. Muscles below the flag threshold are omitted, so a supple
//  body shows the affirmation rather than a wall of empty bars.
//

import SwiftUI

struct MobilitySection: View {
    let board: MuscleTightnessBoard

    private static let monoRow = Font.system(size: 17, weight: .bold, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Mobility", trailing: "tightness")

            insightLine

            if board.hasTight {
                VStack(spacing: Space.lg) {
                    ForEach(board.readings) { reading in
                        row(reading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insight

    @ViewBuilder
    private var insightLine: some View {
        if board.hasTight {
            let names = board.readings.prefix(3).map { InsightsFormat.rowLabel(for: $0.muscle) }
            Text(tightInsight(names: Array(names)))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Nothing's tightened up — your mobility is keeping pace with your training.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone: tight muscle names brightened against dim copy.
    private func tightInsight(names: [String]) -> AttributedString {
        var lead = AttributedString("Tightened up: ")
        lead.foregroundColor = Ink.secondary
        var list = AttributedString(names.joined(separator: ", "))
        list.foregroundColor = Ink.primary
        var tail = AttributedString(names.count == 1 ? " — stretch it to calm the pulse on the figure." : " — stretch them to calm the pulse on the figure.")
        tail.foregroundColor = Ink.secondary
        return lead + list + tail
    }

    // MARK: - Row

    private func row(_ reading: MuscleTightnessReading) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(InsightsFormat.rowLabel(for: reading.muscle))
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)

                Spacer(minLength: Space.sm)

                Text("\(Int((reading.tightness * 100).rounded()))%")
                    .font(Self.monoRow)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
            }

            TightnessBar(value: reading.tightness)
        }
    }
}

// MARK: - Tightness bar

/// A muscle's tightness drawn against a full-width track. Neutral
/// luminance fill — the cool colour is reserved for the 3D body.
private struct TightnessBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Surface.cardTint)
                Capsule()
                    .fill(Ink.secondary)
                    .frame(width: w * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
        .accessibilityLabel(Text("\(Int((value * 100).rounded())) percent tight"))
    }
}
