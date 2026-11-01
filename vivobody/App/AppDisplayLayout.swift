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
import UIKit

/// How many panes the current window gives the tabs.
///
/// - `compact`: every tab shows one column, as on a phone. Every
///   compact-width window resolves here, including iPhone Duo's outer
///   display, and so does every window that is not wider than tall, such
///   as the open iPhone Duo held upright.
/// - `regular`: list-and-detail tabs (History, Library) show both columns;
///   dashboards (Today, Insights) keep one column. A regular-width window
///   wider than tall on a system without fold-aware layout stops here.
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
        guard horizontalSizeClass == .regular, !Self.usesPhoneWidth(windowSize: windowSize) else {
            self = .compact
            return
        }
        let isWide = windowSize.width > windowSize.height
        self = isWide && supportsFoldLayout ? .regularWide : .regular
    }

    /// A window that is not wider than tall gets the phone's compact width,
    /// even where the system reports a regular width.
    static func usesPhoneWidth(windowSize: CGSize) -> Bool {
        windowSize.width > 0 && windowSize.width <= windowSize.height
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

/// How the expanded workout is presented over the shell.
///
/// - `sheet`: a large sheet. Its content keeps one column.
/// - `cover`: a full-window cover. Its content follows the window's layout.
///   A device with a hinge uses it in every pose, so a fold or an unfold
///   only resizes the workout; iOS cannot turn a sheet into a cover while it
///   is on screen. A window that splits dashboards uses it too.
enum ActiveWorkoutPresentation: Equatable {
    case sheet
    case cover

    init(layout: AppDisplayLayout, hasHinge: Bool) {
        self = hasHinge || layout.showsDashboardColumns ? .cover : .sheet
    }

    /// The layout the workout's content reads in this presentation.
    func contentLayout(for layout: AppDisplayLayout) -> AppDisplayLayout {
        switch self {
        case .sheet: layout.showsDashboardColumns ? .regular : layout
        case .cover: layout
        }
    }
}

/// Holds one presentation from the expansion to the minimize. A layout
/// change while the workout is open must not swap presentations: the swap
/// would close the workout, show the shell, and open it again, which also
/// tears down its child sheets and ends a scrub.
struct ActiveWorkoutPresentationLatch: Equatable {
    private(set) var latched: ActiveWorkoutPresentation?

    func presentation(for layout: AppDisplayLayout, hasHinge: Bool) -> ActiveWorkoutPresentation {
        latched ?? ActiveWorkoutPresentation(layout: layout, hasHinge: hasHinge)
    }

    mutating func update(isExpanded: Bool, layout: AppDisplayLayout, hasHinge: Bool) {
        if !isExpanded {
            latched = nil
        } else if latched == nil {
            latched = ActiveWorkoutPresentation(layout: layout, hasHinge: hasHinge)
        }
    }
}

extension EnvironmentValues {
    /// Views outside the shell, such as previews, keep the phone layout.
    /// AppRoot passes the shell's value into the presented workout.
    @Entry var appDisplayLayout: AppDisplayLayout = .compact
}

extension View {
    /// Measures the window, writes the result to `layout`, and publishes it
    /// as `\.appDisplayLayout` to this subtree. Apply once, on the shell's
    /// TabView.
    func readsAppDisplayLayout(into layout: Binding<AppDisplayLayout>) -> some View {
        modifier(AppDisplayLayoutReader(layout: layout))
    }
}

private struct AppDisplayLayoutReader: ViewModifier {
    @Binding var layout: AppDisplayLayout
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var windowSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .environment(\.appDisplayLayout, measuredLayout)
            .onChange(of: measuredLayout, initial: true) { _, newLayout in
                layout = newLayout
            }
            .background {
                // The override reaches the whole window, so split views,
                // sheets, and container-relative frames also behave as on
                // a phone. It follows the window's shape only, never the
                // size class it changes.
                WindowCompactWidthOverride(
                    isActive: AppDisplayLayout.usesPhoneWidth(windowSize: windowSize)
                )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
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

    private var measuredLayout: AppDisplayLayout {
        AppDisplayLayout(
            horizontalSizeClass: horizontalSizeClass,
            windowSize: windowSize,
            supportsFoldLayout: AppDisplayLayout.systemSupportsFoldLayout
        )
    }
}

private struct WindowCompactWidthOverride: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context _: Context) -> OverrideView {
        let view = OverrideView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: OverrideView, context _: Context) {
        view.isActive = isActive
    }

    final class OverrideView: UIView {
        var isActive = false {
            didSet { apply() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else { return }
            let isApplied = window.traitOverrides.contains(UITraitHorizontalSizeClass.self)
            if isActive, !isApplied {
                window.traitOverrides.horizontalSizeClass = .compact
            } else if !isActive, isApplied {
                window.traitOverrides.remove(UITraitHorizontalSizeClass.self)
            }
        }
    }
}
