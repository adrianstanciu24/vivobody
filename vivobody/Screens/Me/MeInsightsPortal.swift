//
//  MeInsightsPortal.swift
//  vivobody
//
//  Focused Me-tab portal into Insights. Copy arrives in the immutable Me
//  presentation while the shell supplies the navigation action.
//

import SwiftUI
import VivoKit

struct MeInsightsPortal: View {
    let presentation: MePresentation.Insights
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        Text(presentation.eyebrow)
                            .font(Typography.metricMicro)
                            .foregroundStyle(Tint.primary)
                            .tracking(1.2)
                        Capsule()
                            .fill(Tint.primary)
                            .frame(width: 22, height: 3)
                            .shadow(color: Tint.primary.opacity(0.55), radius: 5)
                    }

                    Text(presentation.title)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .multilineTextAlignment(.leading)

                    Text(presentation.detail)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                MeInsightPortalMark()
                    .frame(width: 94, height: 104)
                    .accessibilityHidden(true)
            }
            .padding(Space.xl)
            .contentCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityHint)
    }
}

/// Compact oscilloscope-like mark: three signals cross a glowing core so the
/// destination reads as analysis rather than another settings row.
private struct MeInsightPortalMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tint.primary.opacity(0.25),
                            Tint.primary.opacity(0.06),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 48
                    )
                )

            Canvas { context, size in
                let rows: [[CGPoint]] = [
                    [
                        CGPoint(x: 0, y: size.height * 0.67),
                        CGPoint(x: size.width * 0.24, y: size.height * 0.52),
                        CGPoint(x: size.width * 0.45, y: size.height * 0.59),
                        CGPoint(x: size.width * 0.67, y: size.height * 0.29),
                        CGPoint(x: size.width, y: size.height * 0.36),
                    ],
                    [
                        CGPoint(x: 0, y: size.height * 0.34),
                        CGPoint(x: size.width * 0.25, y: size.height * 0.41),
                        CGPoint(x: size.width * 0.50, y: size.height * 0.30),
                        CGPoint(x: size.width * 0.73, y: size.height * 0.56),
                        CGPoint(x: size.width, y: size.height * 0.48),
                    ],
                    [
                        CGPoint(x: 0, y: size.height * 0.76),
                        CGPoint(x: size.width * 0.30, y: size.height * 0.70),
                        CGPoint(x: size.width * 0.53, y: size.height * 0.76),
                        CGPoint(x: size.width * 0.78, y: size.height * 0.64),
                        CGPoint(x: size.width, y: size.height * 0.68),
                    ],
                ]
                let colors: [Color] = [
                    Tint.primary,
                    Ink.primary.opacity(0.60),
                    Ink.primary.opacity(0.24),
                ]

                for (index, points) in rows.enumerated() {
                    var path = Path()
                    guard let first = points.first else { continue }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(colors[index]),
                        style: StrokeStyle(
                            lineWidth: index == 0 ? 2.5 : 1.2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
            .padding(.vertical, Space.md)

            Circle()
                .stroke(Tint.primary.opacity(0.36), lineWidth: 1)
                .frame(width: 42, height: 42)
            Circle()
                .fill(Tint.primary)
                .frame(width: 7, height: 7)
                .shadow(color: Tint.primary.opacity(0.8), radius: 7)
        }
    }
}
