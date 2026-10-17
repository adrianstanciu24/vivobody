//
//  ScrubberCardSurface.swift
//  vivobody
//
//  Liquid-card chrome for BareScrubber's card presentation. The fill
//  height tracks the value's position in its range.
//

import SwiftUI
import VivoKit

/// Kept apart from BareScrubber so card chrome never owns gesture or detent state.
struct ScrubberCardSurface: ViewModifier {
    let isPresented: Bool
    let label: String?
    let verticalPadding: CGFloat
    let fraction: Double
    let isDragging: Bool

    func body(content: Content) -> some View {
        if isPresented {
            VStack(spacing: 4) {
                if let label {
                    Text(label)
                        .sectionLabelStyle(Opacity.medium)
                }
                content
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, verticalPadding)
            .background {
                ScrubberLiquidFill(fraction: fraction, isDragging: isDragging)
            }
            .glassChip(cornerRadius: Radius.card, tint: isDragging ? Tint.primary : nil, interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 0.6)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: isDragging ? Tint.primary.opacity(0.35) : .black.opacity(0.45),
                radius: isDragging ? 14 : 8,
                y: isDragging ? 5 : 3
            )
            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        } else {
            content
        }
    }
}

private struct ScrubberLiquidFill: View {
    let fraction: Double
    let isDragging: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let highlight = Color(.sRGB, red: 1, green: 0.93, blue: 0.84, opacity: 1)

    var body: some View {
        GeometryReader { proxy in
            let tint = isEnabled ? Tint.primary : Ink.tertiary
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [
                        tint.opacity(isDragging ? 0.14 : 0.08),
                        tint.opacity(isDragging ? 0.42 : 0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            Self.highlight.opacity(0),
                            Self.highlight.opacity(isDragging ? 0.55 : 0.40),
                            Self.highlight.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 5)
                    .offset(y: -2.5)
                    .blur(radius: 0.6)
                    .opacity(fraction > 0.02 ? 1 : 0)
                }
                .frame(height: max(0, proxy.size.height * fraction))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: fraction)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isDragging)
        .allowsHitTesting(false)
    }
}
