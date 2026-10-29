//
//  AppDisplayLayout.swift
//  vivobody
//
//  The one rule that decides how much hierarchy the shell's tabs show at
//  once. AppRoot measures the window above its TabView and publishes the
//  result as `\.appDisplayLayout`; screens read that value and never test
//  size classes, orientation, idiom, `UIScreen`, or device names.
//

import SwiftUI

/// How many panes the current window gives the tabs.
///
/// - `compact`: every tab shows one column. Every compact-width window
///   resolves here, including iPhone Duo's outer display.
/// - `regular`: list-and-detail tabs (History, Library) show both columns;
///   dashboards (Today, Insights) keep one column. A regular-width window
///   that is not wider than tall, or a system without fold-aware layout,
///   stops here.
/// - `regularWide`: a regular-width window wider than tall on a system with
///   fold-aware layout. Dashboards split into two columns clear of the fold.
enum AppDisplayLayout: Equatable {
    case compact
    case regular
    case regularWide

    init(
        horizontalSizeClass: UserInterfaceSizeClass?,
        windowSize: CGSize,
        supportsFoldLayout: Bool
    ) {
        guard horizontalSizeClass == .regular else {
            self = .compact
            return
        }
        let isWide = windowSize.width > windowSize.height
        self = isWide && supportsFoldLayout ? .regularWide : .regular
    }

    var showsBrowserDetail: Bool {
        self != .compact
    }

    var showsDashboardColumns: Bool {
        self == .regularWide
    }

    /// ArrangementView and reserved fold regions arrive in iOS 27.1.
    static var systemSupportsFoldLayout: Bool {
        if #available(iOS 27.1, *) { true } else { false }
    }
}

extension EnvironmentValues {
    /// Views outside the shell, such as previews and the active workout
    /// sheet, keep the phone layout.
    @Entry var appDisplayLayout: AppDisplayLayout = .compact
}

extension View {
    /// Publishes `\.appDisplayLayout` to this subtree. Apply once, on the
    /// shell's TabView.
    func readsAppDisplayLayout() -> some View {
        modifier(AppDisplayLayoutReader())
    }
}

private struct AppDisplayLayoutReader: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var windowSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .environment(
                \.appDisplayLayout,
                AppDisplayLayout(
                    horizontalSizeClass: horizontalSizeClass,
                    windowSize: windowSize,
                    supportsFoldLayout: AppDisplayLayout.systemSupportsFoldLayout
                )
            )
            .background {
                // Measured with every safe area ignored, the keyboard
                // included: a keyboard inset would make a tall window read
                // as wide and swap Library's layout in the middle of a search.
                Color.clear
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        windowSize = size
                    }
                    .accessibilityHidden(true)
            }
    }
}
