//
//  BrowserColumns.swift
//  vivobody
//
//  List-and-detail navigation for a browsing tab. One NavigationSplitView
//  shows the selected item's detail beside the list in regular width and
//  collapses to the familiar list-then-push stack in compact width, so a
//  fold or unfold keeps the same navigation state instead of swapping
//  trees. The feature owns the selection as a plain ID value; this
//  container owns only which column is showing and where the columns meet.
//

import SwiftUI
import VivoKit

/// Row commands for a browser list. IDs are value keys such as UUIDs, never
/// SwiftData models, so a route can never hold a stale record.
struct BrowserNavigation<ID: Hashable> {
    /// True when the detail sits beside the list: rows then read as a
    /// selection instead of a push.
    let showsDetailBeside: Bool
    let selectedID: ID?
    fileprivate let openAction: (ID) -> Void
    fileprivate let showListAction: () -> Void

    func isHighlighted(_ id: ID) -> Bool {
        showsDetailBeside && selectedID == id
    }

    /// Selects the item and, in compact width, pushes its detail.
    func open(_ id: ID) {
        openAction(id)
    }

    /// Returns a collapsed browser to its list. No visible change when both
    /// columns show.
    func showList() {
        showListAction()
    }
}

struct BrowserColumns<ID: Hashable, Sidebar: View, Detail: View>: View {
    @Binding var selection: ID?
    @ViewBuilder let sidebar: (BrowserNavigation<ID>) -> Sidebar
    @ViewBuilder let detail: (ID?, BrowserNavigation<ID>) -> Detail

    @Environment(\.appDisplayLayout) private var displayLayout

    /// Only `open` moves this to the detail. A default selection chosen by
    /// the feature therefore never pushes, and compact launch shows the list.
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var geometry = BrowserColumnGeometry()

    var body: some View {
        let navigation = BrowserNavigation(
            showsDetailBeside: displayLayout.showsBrowserDetail,
            selectedID: selection,
            openAction: { id in
                selection = id
                compactColumn = .detail
            },
            showListAction: { compactColumn = .sidebar }
        )
        let widths = BrowserColumnWidths(geometry, splitsAtFold: displayLayout.showsDashboardColumns)
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            // Every layout sets the widths through the same modifiers, so a
            // change of window shape keeps the list's scroll and search state.
            sidebar(navigation)
                .navigationSplitViewColumnWidth(
                    min: widths.isPinned ? widths.list : nil,
                    ideal: widths.list,
                    max: widths.isPinned ? widths.list : nil
                )
        } detail: {
            NavigationStack {
                detail(selection, navigation)
            }
            // Without a zero minimum, the system judges the detail beside a
            // pinned list too narrow and hides the list or lays it over the
            // detail.
            .navigationSplitViewColumnWidth(
                min: widths.isPinned ? 0 : nil,
                ideal: widths.detail
            )
            // A new selection starts a fresh detail stack, so drill-outs
            // from the previous item never linger under the next one.
            .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: BrowserColumnGeometry.self) { proxy in
                    var folds: [CGRect] = []
                    if #available(iOS 27.1, *) {
                        // A fully open device reports its fold as inactive,
                        // but the fold still splits the display in two.
                        folds = proxy.reservedRegions(kind: .division, options: .includeInactive).map(\.frame)
                    }
                    return BrowserColumnGeometry(width: proxy.size.width, folds: folds)
                } action: { measured in
                    geometry = measured
                }
                .accessibilityHidden(true)
        }
    }
}

/// The split view's width and the folds that cross it, active or not, in
/// its own coordinates.
nonisolated struct BrowserColumnGeometry: Equatable {
    var width: CGFloat = 0
    var folds: [CGRect] = []
}

/// The widths of the two columns. A window that splits dashboards pins the
/// list to half the split view, and the detail takes the other half. A fold
/// left of the middle ends the list at the fold instead. The system's own
/// list is about a third of the open iPhone Duo display. The system rejects
/// a list wider than half and falls back to that narrow list, so a fold
/// right of the middle, as on iPhone Duo beside its vertical bars, cannot
/// widen it. Other windows keep a list near the system's width.
nonisolated struct BrowserColumnWidths: Equatable {
    static let standardList: CGFloat = 320

    let list: CGFloat
    let detail: CGFloat
    /// True when the system must not resize the columns.
    let isPinned: Bool

    init(_ geometry: BrowserColumnGeometry, splitsAtFold: Bool) {
        let width = geometry.width
        guard splitsAtFold, width > 0 else {
            list = Self.standardList
            detail = max(0, width - Self.standardList)
            isPinned = false
            return
        }
        let halves = DashboardLanes(width: width, divisions: geometry.folds, gutter: 0, spacing: 0)
        list = min((halves.leading.upperBound + halves.trailing.lowerBound) / 2, width / 2)
        detail = width - list
        isPinned = true
    }
}

/// Keeps a browser's selection valid as its list changes.
enum BrowserSelection {
    /// The current selection while `isValid` accepts it, otherwise `first`.
    /// Applying it again to the same inputs changes nothing.
    static func retainOrFirst<ID: Hashable>(
        _ current: ID?,
        isValid: (ID) -> Bool,
        first: ID?
    ) -> ID? {
        if let current, isValid(current) {
            return current
        }
        return first
    }
}

extension View {
    /// Marks the row whose detail shows beside the list. The outline keeps
    /// the mark readable with Differentiate Without Color.
    func browserRowSelection(_ isSelected: Bool) -> some View {
        background {
            if isSelected {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(Tint.primary.opacity(0.12))
                    .strokeBorder(Tint.primaryDim, lineWidth: 1)
                    .padding(Space.xs)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
