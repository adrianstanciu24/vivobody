//
//  BrowserColumns.swift
//  vivobody
//
//  List-and-detail navigation for a browsing tab. One NavigationSplitView
//  shows the selected item's detail beside the list in regular width and
//  collapses to the familiar list-then-push stack in compact width, so a
//  fold or unfold keeps the same navigation state instead of swapping
//  trees. The feature owns the selection as a plain ID value; this
//  container owns only which column is showing.
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
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            sidebar(navigation)
        } detail: {
            NavigationStack {
                detail(selection, navigation)
            }
            // A new selection starts a fresh detail stack, so drill-outs
            // from the previous item never linger under the next one.
            .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
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
