//
//  MovementPlaneIllustration.swift
//  vivobody
//
//  A standing figure sliced by one anatomical plane. The three planes share a
//  single cabinet projection so they read as one family: the sagittal sheet
//  stands edge-on through the midline, the frontal sheet sits behind the body,
//  and the transverse sheet cuts through the hips. The half of the body on the
//  viewer's side of a sheet is drawn over it, so the plane visibly passes
//  through the figure instead of lying on top of it.
//

import SwiftUI
import VivoKit

struct MovementPlaneIllustration: View {
    let plane: MovementPlane

    /// Reference canvas the geometry is authored in. The view scales it
    /// uniformly to whatever frame it receives.
    static let designSize = CGSize(width: 64, height: 72)

    /// Depth toward the viewer runs down-left at half scale, which keeps the
    /// front-facing symbol undistorted while giving every sheet the same lean.
    private static let depthX: CGFloat = -0.433
    private static let depthY: CGFloat = 0.25
    private static let figurePointSize: CGFloat = 52
    private static let sheetMargin: CGFloat = 5
    private static let halfDepth: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.designSize.width, size.height / Self.designSize.height)
            context.translateBy(
                x: (size.width - Self.designSize.width * scale) / 2,
                y: (size.height - Self.designSize.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)

            var figure = context.resolve(
                Text(Image(systemName: "figure.stand"))
                    .font(.system(size: Self.figurePointSize, weight: .light))
            )
            let layout = FigureLayout(figureSize: figure.measure(in: CGSize(width: 1000, height: 1000)))
            let sheet = Self.sheet(for: plane, layout: layout)

            if let nearRegion = Self.nearRegion(for: plane, layout: layout) {
                figure.shading = .color(Ink.tertiary)
                context.draw(figure, at: layout.center, anchor: .center)
                Self.paint(sheet, in: &context)
                figure.shading = .color(Ink.secondary)
                context.drawLayer { layer in
                    layer.clip(to: nearRegion)
                    layer.draw(figure, at: layout.center, anchor: .center)
                }
            } else {
                Self.paint(sheet, in: &context)
                figure.shading = .color(Ink.secondary)
                context.draw(figure, at: layout.center, anchor: .center)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Geometry

    /// Visible body extents inside the symbol's line box, tuned by eye.
    private struct FigureLayout {
        let center = CGPoint(
            x: MovementPlaneIllustration.designSize.width / 2,
            y: MovementPlaneIllustration.designSize.height / 2
        )
        let top: CGFloat
        let bottom: CGFloat
        let halfWidth: CGFloat
        let hips: CGFloat

        init(figureSize: CGSize) {
            top = center.y - figureSize.height * 0.43
            bottom = center.y + figureSize.height * 0.43
            halfWidth = figureSize.width / 2
            hips = center.y + figureSize.height * 0.05
        }
    }

    private struct Sheet {
        var path: Path
        var gradientStart: CGPoint
        var gradientEnd: CGPoint
        var startOpacity: Double
        var endOpacity: Double
    }

    private static func project(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        CGPoint(x: x + z * depthX, y: y + z * depthY)
    }

    private static func sheet(for plane: MovementPlane, layout: FigureLayout) -> Sheet {
        let cx = layout.center.x
        let top = layout.top - sheetMargin
        let bottom = layout.bottom + sheetMargin
        let halfWidth = layout.halfWidth + sheetMargin
        let corners: [CGPoint]
        var sheet: Sheet
        switch plane {
        case .sagittal:
            corners = [
                project(cx, top, halfDepth), project(cx, top, -halfDepth),
                project(cx, bottom, -halfDepth), project(cx, bottom, halfDepth),
            ]
            sheet = Sheet(
                path: Path(), gradientStart: project(cx, layout.center.y, halfDepth),
                gradientEnd: project(cx, layout.center.y, -halfDepth), startOpacity: 0.36, endOpacity: 0.08
            )
        case .frontal:
            corners = [
                project(cx - halfWidth, top, 0), project(cx + halfWidth, top, 0),
                project(cx + halfWidth, bottom, 0), project(cx - halfWidth, bottom, 0),
            ]
            // No near edge to weight; light it from the corner the depth axis leans toward.
            sheet = Sheet(
                path: Path(), gradientStart: CGPoint(x: cx - halfWidth, y: bottom),
                gradientEnd: CGPoint(x: cx + halfWidth, y: top), startOpacity: 0.16, endOpacity: 0.04
            )
        case .transverse:
            corners = [
                project(cx - halfWidth, layout.hips, halfDepth), project(cx + halfWidth, layout.hips, halfDepth),
                project(cx + halfWidth, layout.hips, -halfDepth), project(cx - halfWidth, layout.hips, -halfDepth),
            ]
            sheet = Sheet(
                path: Path(), gradientStart: project(cx, layout.hips, halfDepth),
                gradientEnd: project(cx, layout.hips, -halfDepth), startOpacity: 0.36, endOpacity: 0.08
            )
        }
        sheet.path.addLines(corners)
        sheet.path.closeSubpath()
        return sheet
    }

    /// The part of the body between the viewer and the sheet. Nil when the
    /// whole visible front of the body is on the viewer's side.
    private static func nearRegion(for plane: MovementPlane, layout: FigureLayout) -> Path? {
        let bounds = CGRect(origin: .zero, size: designSize).insetBy(dx: -100, dy: -100)
        switch plane {
        case .sagittal:
            return Path(CGRect(x: layout.center.x, y: bounds.minY, width: bounds.maxX - layout.center.x, height: bounds.height))
        case .frontal:
            return nil
        case .transverse:
            return Path(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: layout.hips - bounds.minY))
        }
    }

    private static func paint(_ sheet: Sheet, in context: inout GraphicsContext) {
        context.fill(sheet.path, with: .linearGradient(
            Gradient(colors: [Tint.primary.opacity(sheet.startOpacity), Tint.primary.opacity(sheet.endOpacity)]),
            startPoint: sheet.gradientStart, endPoint: sheet.gradientEnd
        ))
        context.stroke(sheet.path, with: .color(Tint.primary), lineWidth: 1.25)
    }
}

#if DEBUG
    #Preview("Movement planes") {
        HStack(spacing: Space.xxl) {
            ForEach(MovementPlane.allCases, id: \.self) { plane in
                MovementPlaneIllustration(plane: plane)
                    .frame(width: 128, height: 144)
            }
        }
        .padding(Space.xxl)
        .contentCard()
        .padding(Space.gutter)
    }
#endif
