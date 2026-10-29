//
//  TodaySplitContent.swift
//  vivobody
//
//  Today on a wide, regular-width window: the trained body and its one start
//  action fill the leading pane, and Up next, Consistency, and Last workout
//  scroll on their own in the trailing pane. The enclosing NavigationStack
//  still owns both panes, so their drill-outs push over the whole tab.
//

import SwiftUI
import VivoKit

@available(iOS 27.1, *)
extension TodayScreen {
    func splitContent(upNext: UpNext) -> some View {
        ArrangementView {
            bodyPane
        } secondary: {
            detailsPane(upNext: upNext)
        }
        .arrangementViewStyle(.split.axes(.horizontal))
    }

    /// No scroll transition here: the figure keeps one frame while either
    /// pane scrolls. The start bar is the only one on the screen.
    private var bodyPane: some View {
        ScrollView {
            bodySection
                .padding(.top, Space.xs)
                .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        // Set before the bar: an identifier on the whole pane would replace
        // the start button's own identifier.
        .accessibilityIdentifier("todayBodyPane")
        .safeAreaBar(edge: .bottom, spacing: 0) {
            pinnedStartBar
        }
        // The large title collapses when either pane scrolls; reading the
        // top inset keeps that from re-scaling the figure that stays on screen.
        .onGeometryChange(for: TodayHeroSizing.Container.self) { proxy in
            TodayHeroSizing.Container(size: proxy.size, topInset: proxy.safeAreaInsets.top)
        } action: { container in
            heroSizing.accept(container)
        }
    }

    private func detailsPane(upNext: UpNext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                // Up next leads this pane, so without it nothing sits above
                // Consistency to divide from.
                if barSession == nil {
                    upNextSection(upNext)
                    SectionDivider()
                }
                consistencySection
                SectionDivider()
                lastWorkoutSection
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("todayDetailsPane")
    }
}
