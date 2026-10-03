//
//  ScrubGraduationRail.swift
//  vivobody
//
//  A drum of fine graduations with a fixed index. At rest it stays neutral and
//  low-contrast beside the value; it brightens only while the value moves.
//  Subdivisions keep short rails legible without changing the scrubber's
//  value detents.
//

import SwiftUI
import VivoKit

struct ScrubGraduationRail: View {
    static let width: CGFloat = 16

    let value: Double
    let step: Double
    let spacing: CGFloat
    let visible: Bool
    var engaged: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            Canvas { context, size in
                drawGraduations(in: &context, size: size)
            }
            .opacity(engaged ? 1 : restingScaleOpacity)

            // The index outspans every graduation, so its shape still marks
            // the value when the accent color is not perceived.
            Capsule()
                .fill(engaged ? Tint.primaryText : Ink.tertiary)
                .frame(width: Self.width, height: engaged ? 2 : 1.5)
        }
        .frame(width: Self.width)
        .opacity(visible ? 1 : 0)
        .animation(stateAnimation, value: visible)
        .animation(stateAnimation, value: engaged)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var stateAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var restingScaleOpacity: Double {
        contrast == .increased ? 0.8 : 0.5
    }

    private func drawGraduations(in context: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        guard midY > 0 else { return }
        // Short rails subdivide each detent so a compact reps rail still reads
        // as a scale. Intermediate marks carry no values.
        let targetPitch = max(4, min(7, size.height / 9))
        let subdivisions = max(1, Int((spacing / targetPitch).rounded()))
        let pitch = spacing / CGFloat(subdivisions)
        let position = value / max(step, .ulpOfOne) * Double(subdivisions)
        let baseIndex = Int(position.rounded(.down))
        let fraction = CGFloat(position - Double(baseIndex))
        let reach = Int(midY / pitch) + 2
        let increasedContrast = contrast == .increased

        for offset in -reach ... reach {
            let distance = (CGFloat(offset) - fraction) * pitch
            let normalized = distance / midY
            guard abs(normalized) < 1 else { continue }
            // Sine spacing compresses marks toward the ends, as on a drum.
            let y = midY + sin(normalized * .pi / 2) * midY
            let mark = Mark(index: baseIndex + offset, subdivisions: subdivisions)
            let edgeFade = pow(cos(normalized * .pi / 2), 1.4)
            // Marks pass beneath the index instead of doubling it.
            let indexClearance = min(1, abs(y - midY) / 3)
            let opacity = mark.strength(increasedContrast: increasedContrast) * edgeFade * indexClearance
            guard opacity > 0.01 else { continue }
            let rect = CGRect(x: size.width - mark.length, y: y - 0.5, width: mark.length, height: 1)
            context.fill(Path(rect), with: .color(Ink.primary.opacity(opacity)))
        }
    }

    private enum Mark {
        case major
        case detent
        case subdivision

        init(index: Int, subdivisions: Int) {
            if index.isMultiple(of: subdivisions * 5) {
                self = .major
            } else if index.isMultiple(of: subdivisions) {
                self = .detent
            } else {
                self = .subdivision
            }
        }

        var length: CGFloat {
            switch self {
            case .major: 9
            case .detent: 6
            case .subdivision: 3.5
            }
        }

        func strength(increasedContrast: Bool) -> Double {
            switch self {
            case .major: increasedContrast ? 1 : 0.85
            case .detent: increasedContrast ? 0.9 : 0.6
            case .subdivision: increasedContrast ? 0.6 : 0.34
            }
        }
    }
}
