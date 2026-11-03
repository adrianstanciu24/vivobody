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
    private let content: (DashboardLanes?) -> Content
    private let usesLanes: Bool
    @Environment(\.appDisplayLayout) private var displayLayout

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = { _ in content() }
        usesLanes = false
    }

    /// Content that receives the two lanes beside the fold on a window that
    /// splits dashboards, and nil on every other window.
    init(title: String, @ViewBuilder content: @escaping (DashboardLanes?) -> Content) {
        self.title = title
        self.content = content
        usesLanes = true
    }

    var body: some View {
        Group {
            if usesLanes, displayLayout.showsDashboardColumns, #available(iOS 27.1, *) {
                // Read outside the scroll: the fold stays put while the cards move.
                GeometryReader { viewport in
                    scroll(content(DashboardLanes(
                        width: viewport.size.width,
                        divisions: viewport.reservedRegions(kind: .division).map(\.frame)
                    )))
                }
            } else {
                scroll(content(nil))
                    .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            }
        }
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scroll(_ content: Content) -> some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
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
