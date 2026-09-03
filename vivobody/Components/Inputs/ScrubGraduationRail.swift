//
//  ScrubGraduationRail.swift
//  vivobody
//
//  Stateless Canvas rendering for BareScrubber's transient detent rail.
//

import SwiftUI
import VivoKit

struct ScrubGraduationRail: View {
    let value: Double
    let step: Double
    let spacing: CGFloat
    let visible: Bool

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let stepsFromZero = value / max(step, .ulpOfOne)
            let baseIndex = Int(stepsFromZero.rounded(.down))
            let fraction = CGFloat(stepsFromZero - Double(baseIndex))
            let reach = Int(midY / spacing) + 2

            for offset in -reach ... reach {
                let index = baseIndex + offset
                let y = midY + (CGFloat(offset) - fraction) * spacing
                guard y >= 0, y <= size.height else { continue }
                let isMajor = ((index % 5) + 5) % 5 == 0
                let width: CGFloat = isMajor ? 14 : 8
                let centerDistance = abs(y - midY) / max(midY, 1)
                let edgeFade = pow(max(0, 1 - centerDistance), 1.5)
                let opacity = (isMajor ? 0.55 : 0.30) * edgeFade
                context.fill(
                    Path(CGRect(x: size.width - width, y: y - 0.5, width: width, height: 1)),
                    with: .color(Ink.primary.opacity(opacity))
                )
            }

            context.fill(
                Path(CGRect(x: size.width - 18, y: midY - 0.75, width: 18, height: 1.5)),
                with: .color(Tint.primary.opacity(0.9))
            )
        }
        .frame(width: 22)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.16), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
