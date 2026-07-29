//
//  SpecimenStage.swift
//  vivobody
//
//  The instrument mount for the Today figure. Physical devices never
//  float their display object — a specimen sits on a stage, a gauge
//  needle rides a printed scale. This file grounds the anatomical
//  model with three quiet layers, all behavior and hairlines, never
//  texture (see PanelKit for the no-skeuomorphism rule):
//
//    • SpecimenStage — the elliptical turntable under the feet: a warm
//      contact glow (heat off the chassis, brightness tied to the same
//      forgeWarmth the seam burns at), a hairline rim, and degree
//      ticks that track the model's rotation 1:1, so spinning the body
//      reads as spinning a physical stage.
//    • SilkscreenGraticule — registration brackets bounding the
//      rotatable zone plus the facing dial printed along its top edge,
//      the same screen-print vocabulary as the panel legends. The dial
//      names which aspect of the figure is turned toward you, so the
//      brackets frame a readout rather than decorating a picture.
//    • StagedBodyModel — the composition Today mounts. The live
//      rotation state lives HERE so per-frame rotation updates
//      re-render only this small subtree, never the whole Today screen
//      (a full-screen body re-eval per frame is what once made the
//      hero scroll feel like slow motion).
//

import SwiftUI

// MARK: - Turntable

struct SpecimenStage: View {
    /// Model rotation about the vertical axis, radians. The ticks
    /// track it 1:1 so stage and figure turn as one piece.
    var rotation: Double

    /// forgeWarmth (0–1): drives the contact glow, so the figure
    /// stands over the same heat the seam leaks at the screen edges.
    var warmth: Double

    @Environment(\.colorScheme) private var colorScheme

    /// Vertical squash of the floor ellipse — the camera's downward
    /// angle onto the floor plane (atan(0.9 / 3.0) ≈ 17°, sin ≈ 0.29).
    private let squash: CGFloat = 0.29

    var body: some View {
        Canvas { context, size in
            let dark = colorScheme == .dark
            let cx = size.width / 2
            let cy = size.height / 2
            let rx = size.width / 2 - 8
            let ry = rx * squash

            // Contact glow: the pool of chassis heat the figure stands
            // over. Drawn as a circle in a squashed copy of the context
            // so the falloff stays radially even on the floor plane.
            let glowPeak = dark ? 0.10 + 0.22 * warmth : 0.14 + 0.18 * warmth
            let ember = dark
                ? Color(.sRGB, red: 1.0, green: 0.42, blue: 0.0, opacity: glowPeak)
                : Color(.sRGB, red: 1.0, green: 0.60, blue: 0.32, opacity: glowPeak)
            var floor = context
            floor.translateBy(x: cx, y: cy)
            floor.scaleBy(x: 1, y: squash)
            floor.fill(
                Path(ellipseIn: CGRect(x: -rx, y: -rx, width: rx * 2, height: rx * 2)),
                with: .radialGradient(
                    Gradient(colors: [ember, ember.opacity(0)]),
                    center: .zero, startRadius: 0, endRadius: rx
                )
            )

            // Rim: one hairline, the machined edge of the turntable.
            let rim = dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)),
                with: .color(rim),
                lineWidth: 1
            )

            // Degree ticks, majors at the quarter turns. Screen angle t
            // is the world angle minus the model rotation (a positive
            // eulerAngles.y turn carries the front of the disc toward
            // +X), so the ticks ride the same turntable as the figure.
            // Far-side ticks dim the way the far rim of a real disc
            // falls into shade.
            let tickCount = 24
            for i in 0..<tickCount {
                let t = Double(i) / Double(tickCount) * 2 * .pi - rotation
                let major = i % 6 == 0
                let len: CGFloat = major ? 7 : 4
                let near = (sin(t) + 1) / 2
                let base = major ? 0.20 : 0.13
                let alpha = base * (0.30 + 0.70 * near)
                let ink = dark ? Color.white.opacity(alpha) : Color.black.opacity(alpha)

                var path = Path()
                path.move(to: CGPoint(
                    x: cx + CGFloat(cos(t)) * (rx - len),
                    y: cy + CGFloat(sin(t)) * (ry - len * squash)
                ))
                path.addLine(to: CGPoint(
                    x: cx + CGFloat(cos(t)) * rx,
                    y: cy + CGFloat(sin(t)) * ry
                ))
                context.stroke(path, with: .color(ink), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Faceplate printing

/// Registration brackets at the corners of the display zone plus the
/// facing dial printed along its top edge — the screen printing around
/// an instrument's viewport. The brackets bound the zone the drag
/// rotates; the dial slides beneath a fixed index as the model turns
/// and the aspect under that index is named in the corner, so a spin
/// reads as an absolute facing (FRONT, BACK, either side) rather than
/// an unlabelled wobble. Pure hairlines at silkscreen opacity; it
/// frames the figure without ever competing with it.
struct SilkscreenGraticule: View {
    /// Model rotation about the vertical axis, radians — the same
    /// value the turntable ticks ride.
    var rotation: Double

    @Environment(\.colorScheme) private var colorScheme

    /// The printed zone: how far the brackets sit in from the render
    /// edges, and how long each bracket leg runs.
    private let inset: CGFloat = 14
    private let arm: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let dark = colorScheme == .dark
            let ink = dark ? Color.white.opacity(0.13) : Color.black.opacity(0.13)
            let type = dark ? Color.white.opacity(0.26) : Color.black.opacity(0.26)
            let index = dark ? Color.white.opacity(0.34) : Color.black.opacity(0.34)
            let frame = CGRect(origin: .zero, size: size)
                .insetBy(dx: inset, dy: 4)

            var brackets = Path()
            for (x, dx) in [(frame.minX, 1.0), (frame.maxX, -1.0)] {
                for (y, dy) in [(frame.minY, 1.0), (frame.maxY, -1.0)] {
                    brackets.move(to: CGPoint(x: x + arm * dx, y: y))
                    brackets.addLine(to: CGPoint(x: x, y: y))
                    brackets.addLine(to: CGPoint(x: x, y: y + arm * dy))
                }
            }
            context.stroke(brackets, with: .color(ink), lineWidth: 1)

            drawFacingDial(
                in: context,
                frame: frame,
                ink: ink,
                type: type,
                index: index
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The facing readout, printed between the two top brackets: a
    /// scale of quarter-turn ticks riding the model's rotation under a
    /// fixed index caret, with the aspect under that caret named in the
    /// corner. Turning the figure right carries the scale right with
    /// the chest, and the name changes as each quarter comes around.
    /// The name is printed in the corner rather than on the scale
    /// because the figure fills the frame top to bottom — a label at
    /// the centre would land on its skull.
    private func drawFacingDial(
        in context: GraphicsContext,
        frame: CGRect,
        ink: Color,
        type: Color,
        index: Color
    ) {
        let window = CGRect(
            x: frame.minX + arm + 6,
            y: frame.minY,
            width: frame.width - (arm + 6) * 2,
            height: 20
        )
        guard window.width > 60 else { return }

        // One full turn spans the printed zone's width, so a quarter
        // turn of the figure slides the scale a quarter of the frame.
        let span = frame.width
        let center = window.midX

        var caret = Path()
        caret.move(to: CGPoint(x: center - 4, y: window.minY))
        caret.addLine(to: CGPoint(x: center + 4, y: window.minY))
        caret.addLine(to: CGPoint(x: center, y: window.minY + 5))
        caret.closeSubpath()
        context.fill(caret, with: .color(index))

        var dial = context
        dial.clip(to: Path(window))

        let tickTop = window.minY + 8
        let marks = 12
        var ticks = Path()
        for i in 0..<marks {
            let azimuth = Double(i) / Double(marks) * 2 * .pi
            let x = center + CGFloat(screenOffset(of: azimuth)) * span
            let major = i % 3 == 0
            ticks.move(to: CGPoint(x: x, y: tickTop))
            ticks.addLine(to: CGPoint(x: x, y: tickTop + (major ? 8 : 5)))
        }
        dial.stroke(ticks, with: .color(ink), lineWidth: 1)

        let resolved = context.resolve(
            Text(facingName)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(type)
        )
        context.draw(
            resolved,
            at: CGPoint(x: frame.minX + 2, y: tickTop + 20),
            anchor: .leading
        )
    }

    /// Where a model azimuth lands on the dial, as a fraction of one
    /// full turn either side of the index. A positive `eulerAngles.y`
    /// turn carries the figure's front toward +X, so the scale carries
    /// its marks the same way, wrapped to the nearest half turn so only
    /// the visible arc is ever drawn.
    private func screenOffset(of azimuth: Double) -> Double {
        var offset = (azimuth + rotation).truncatingRemainder(dividingBy: 2 * .pi)
        if offset > .pi { offset -= 2 * .pi }
        if offset < -.pi { offset += 2 * .pi }
        return offset / (2 * .pi)
    }

    /// The aspect under the index caret. The model azimuth facing the
    /// camera is the negated rotation, and the figure faces you, so the
    /// quarter turn that brings its own left side around is the
    /// positive one.
    private var facingName: String {
        let turn = 2 * Double.pi
        var facing = (-rotation).truncatingRemainder(dividingBy: turn)
        if facing < 0 { facing += turn }
        switch facing {
        case (turn * 0.125)..<(turn * 0.375): return "L SIDE"
        case (turn * 0.375)..<(turn * 0.625): return "BACK"
        case (turn * 0.625)..<(turn * 0.875): return "R SIDE"
        default:                              return "FRONT"
        }
    }
}

// MARK: - Mounted composition

/// The figure on its mount: turntable behind, model on top, faceplate
/// printing framing the zone. Owns the live rotation state so the
/// per-frame updates from a spin re-render only this subtree.
struct StagedBodyModel: View {
    var renderHeight: CGFloat
    var channels: [String: MuscleMapChannels]
    var warmth: Double

    @State private var rotation: Double = 0

    /// Where the feet land within the render height, from the camera
    /// maths: a 36° vertical field at 3.0m spans ±0.975 about eye
    /// height 0.9, putting the floor (y = 0) at 1.875 / 1.95 ≈ 0.96
    /// of the frame from the top.
    private let feetLine: CGFloat = 0.962

    var body: some View {
        let stageWidth = renderHeight * 0.48
        let stageHeight = stageWidth * 0.29 + 16

        RotatableBodyModel(
            renderHeight: renderHeight,
            channels: channels,
            onRotation: { rotation = $0 }
        )
        .frame(maxWidth: .infinity)
        .frame(height: renderHeight)
        .background(alignment: .top) {
            SpecimenStage(rotation: rotation, warmth: warmth)
                .frame(width: stageWidth, height: stageHeight)
                .offset(y: feetLine * renderHeight - stageHeight / 2)
        }
        .overlay { SilkscreenGraticule(rotation: rotation) }
    }
}

#Preview("Staged figure") {
    ZStack {
        Color.black.ignoresSafeArea()
        StagedBodyModel(renderHeight: 480, channels: [:], warmth: 0.8)
    }
    .preferredColorScheme(.dark)
}
