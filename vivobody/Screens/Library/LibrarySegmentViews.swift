//
//  LibrarySegmentViews.swift
//  vivobody
//
//  Library scope picker and its padded segment bar. Both wrap the shared
//  SegmentedPicker so the scope switch matches every other segmented
//  choice in the app.
//

import SwiftUI
import VivoKit

// MARK: - Scope picker

/// The Exercises / Templates scope switch. The selection binding carries
/// the animation so LibraryScreen's content swap animates with the thumb.
struct LibrarySegmentPicker: View {
    @Binding var selection: LibrarySegment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SegmentedPicker(
            selection: $selection.animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
            ),
            options: LibrarySegment.allCases,
            font: Typography.sectionHeading,
            label: { $0.label }
        )
    }
}

// MARK: - Segment bar

/// The scope picker wrapped with the screen's standard header padding.
/// Hosted as the first element inside each segment's scroll view so it
/// scrolls away with the content (and lets the large navigation title
/// collapse normally) rather than staying pinned.
struct LibrarySegmentBar: View {
    @Binding var selection: LibrarySegment

    var body: some View {
        LibrarySegmentPicker(selection: $selection)
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
    }
}
