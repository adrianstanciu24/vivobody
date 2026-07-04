//
//  LibrarySegmentViews.swift
//  vivobody
//
//  Segmented control and segment bar components for the Library
//  screen. Extracted from LibraryScreen.swift for file size
//  management.
//

import SwiftUI
import SwiftData

// MARK: - Segmented control

/// A full-width Liquid Glass segmented bar. A shared neutral glass
/// track holds both labels; the selected thumb preserves the solid
/// electric-orange token while gaining the same interactive glass
/// response as the rest of the controls.
struct SegmentedControl: View {
    @Binding var selection: LibrarySegment
    @Namespace private var thumb

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(LibrarySegment.allCases) { segment in
                    segmentButton(segment)
                }
            }
            .padding(4)
            .coloredGlassControl(cornerRadius: Radius.pill)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: selection)
    }

    private func segmentButton(_ segment: LibrarySegment) -> some View {
        let isSelected = selection == segment
        return Button {
            guard selection != segment else { return }
            if reduceMotion {
                selection = segment
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selection = segment
                }
            }
            Haptics.selection()
        } label: {
            Text(segment.label)
                .font(Typography.sectionHeading)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background {
                    if isSelected {
                        Color.clear
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(segment.label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// MARK: - Segment bar

/// The segmented control wrapped with the screen's standard header
/// padding. Hosted as the first element inside each segment's scroll
/// view so it scrolls away with the content (and lets the large
/// navigation title collapse normally) rather than staying pinned.
struct LibrarySegmentBar: View {
    @Binding var selection: LibrarySegment

    var body: some View {
        SegmentedControl(selection: $selection)
            .accessibilityLabel("Library segment")
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
    }
}
