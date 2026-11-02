//
//  InsightsScreenSupport.swift
//  vivobody
//
//  Shared navigation, locked-preview, and empty-state pieces keep the
//  Insights panel and its drill-outs visually consistent without putting
//  analytics decisions in the screen shell.
//

import SwiftUI
import VivoKit

struct InsightsDrilloutScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// Freezes the whole Insights page beneath one blur for the free
    /// version. Nil `onUnlock` renders the page unchanged.
    @ViewBuilder
    func insightsLockedPreview(onUnlock: (() -> Void)?) -> some View {
        if let onUnlock {
            InsightsLockedPreview(title: "Insights", action: onUnlock) { self }
        } else {
            self
        }
    }
}

struct InsightsLockedPreview<Content: View>: View {
    let title: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            content()
                .blur(radius: reduceTransparency ? 0 : 8)
                .opacity(reduceTransparency ? 0 : 0.90)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            Button(action: action) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("insightsLockedPreview")
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(title), locked")
            .accessibilityHint("Unlocks with Vivobody Pro")
        }
    }
}

struct InsightsEmptyMark: View {
    var isLoading = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Tint.primary.opacity(isLoading ? 0.20 : 0.13), .clear],
                center: .center,
                startRadius: 1,
                endRadius: 90
            )

            ForEach(0 ..< 3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        index == 1
                            ? Tint.primary.opacity(isLoading ? 0.62 : 0.38)
                            : Ink.primary.opacity(0.13),
                        lineWidth: index == 1 ? 1.5 : 1
                    )
                    .frame(
                        width: 54 + CGFloat(index) * 34,
                        height: 112 - CGFloat(index) * 22
                    )
                    .rotationEffect(.degrees(Double(index - 1) * 31))
            }

            Circle()
                .fill(Tint.primary)
                .frame(width: 8, height: 8)
                .shadow(color: Tint.primary.opacity(0.78), radius: 9)
        }
    }
}
