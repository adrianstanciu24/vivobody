//
//  FractionBar.swift
//  vivobody
//
//  A horizontal capsule track with a leading capsule fill for one share
//  or ratio. Built on `ProgressView` so the bar carries native progress
//  semantics; the style only draws the Insights instrument look. Rows
//  that already speak the value hide or ignore it for VoiceOver.
//

import SwiftUI
import VivoKit

struct FractionBar: View {
    let value: Double
    let track: Color
    let fill: AnyShapeStyle
    let height: CGFloat

    init(value: Double, track: Color, fill: some ShapeStyle, height: CGFloat) {
        self.value = value
        self.track = track
        self.fill = AnyShapeStyle(fill)
        self.height = height
    }

    private var clampedValue: Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    var body: some View {
        ProgressView(value: clampedValue)
            .progressViewStyle(FractionBarStyle(track: track, fill: fill))
            .frame(height: height)
    }
}

private struct FractionBarStyle: ProgressViewStyle {
    let track: Color
    let fill: AnyShapeStyle

    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: proxy.size.width * fraction)
            }
        }
    }
}

#if DEBUG
    private struct FractionBarGallery: View {
        @State private var value = 0.42

        var body: some View {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Micro · solid").panelLegend()
                FractionBar(value: value, track: Ink.quaternary, fill: Tint.primary, height: InstrumentBarHeight.micro)
                Text("Standard · gradient").panelLegend()
                FractionBar(value: value, track: Surface.cardTintBright, fill: Tint.primary.gradient, height: InstrumentBarHeight.standard)
                Text("Edges").panelLegend()
                FractionBar(value: 0, track: Surface.edge, fill: Tint.primary.gradient, height: InstrumentBarHeight.micro)
                FractionBar(value: 1.4, track: Surface.edge, fill: Tint.primary.gradient, height: InstrumentBarHeight.micro)
                Slider(value: $value, in: 0 ... 1).tint(Tint.primary)
            }
            .padding(Space.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Surface.background.ignoresSafeArea())
        }
    }

    #Preview("Fraction bar") {
        FractionBarGallery().preferredColorScheme(.dark)
    }

    #Preview("Fraction bar · Light") {
        FractionBarGallery().preferredColorScheme(.light)
    }
#endif
