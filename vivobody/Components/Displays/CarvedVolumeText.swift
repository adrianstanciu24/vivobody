//
//  CarvedVolumeText.swift
//  vivobody
//
//  "Pressed into the glass" numerical hero. The value is rendered
//  in tabular monospaced figures with a top-down vertical gradient
//  (darker top, brighter bottom) plus a thin dark shadow above and
//  a faint white halo below — together they read as a number
//  physically carved into the card surface, the way an engraved
//  metal plate catches light only on its lower lip.
//
//  Layout: large carved value, tiny unit subscript baseline-aligned
//  to the right. PR sessions add a hairline gold underline beneath
//  the digits — typographic accent only, no badge chrome.
//
//  Shared between the History row, the Session detail hero, and any
//  future surface that wants to render a volume number as engraved
//  glass type.
//

import SwiftUI

struct CarvedVolumeText: View {
    let value: String
    let unit: String
    var size: CGFloat = 36
    var isPR: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// PR underline uses the one accent — completion/achievement is
    /// the only thing allowed to wear colour.
    private static let prGold = Tint.primary

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .kerning(-0.6)
                    .foregroundStyle(
                        reduceTransparency
                            ? AnyShapeStyle(Ink.primary)
                            : AnyShapeStyle(
                                LinearGradient(
                                    stops: [
                                        .init(color: Ink.primary.opacity(0.58), location: 0.0),
                                        .init(color: Ink.primary.opacity(0.94), location: 1.0),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: .black.opacity(reduceTransparency ? 0 : 0.55), radius: 0.6, x: 0, y: -0.5)
                    .shadow(color: .white.opacity(reduceTransparency ? 0 : 0.10), radius: 0.4, x: 0, y: 0.8)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                        .foregroundStyle(Ink.primary.opacity(Opacity.soft))
                        .padding(.bottom, 2)
                }
            }

            if isPR {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Self.prGold.opacity(0.0), Self.prGold.opacity(0.85), Self.prGold.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(maxWidth: size * 1.6)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
