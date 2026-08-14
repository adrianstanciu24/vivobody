//
//  SwipePager.swift
//  vivobody
//
//  Horizontal pager with center-locked active card and a peek of the
//  neighbors on each side — the Stories-style interaction, applied to
//  workout exercises. Drag with momentum, rubber-band at the edges,
//  haptic tick when crossing into a new card, rigid bump at the walls.
//
//  Use:
//      @State private var index = 0
//      SwipePager(selection: $index, count: items.count) { i in
//          ExerciseCard(item: items[i])
//      }
//      .frame(height: 420)
//

import SwiftUI
import VivoKit

struct SwipePager<Content: View>: View {
    @Binding var selection: Int
    let count: Int
    let content: (Int) -> Content

    var peekWidth: CGFloat = 22
    var spacing: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGFloat = 0
    @State private var lastCrossedIndex: Int = -1
    @State private var didEdgeHaptic: Bool = false
    @State private var isDragging: Bool = false

    /// Compensation applied when `selection` is written externally
    /// mid-drag (the superset auto-advance): the base shifts by one
    /// stride so the content keeps tracking the finger instead of
    /// teleporting, and the release projection stays honest.
    @State private var dragBase: CGFloat = 0

    /// Axis-claim for the current drag.
    ///   nil   — drag just started, not enough movement to decide
    ///   true  — horizontally dominant; SwipePager owns the gesture
    ///   false — vertically dominant; SwipePager yields, letting
    ///           nested gestures (NumberScrubber) handle it
    /// Reset to nil on every onEnded so each new drag re-decides.
    @State private var horizontalAxisLocked: Bool? = nil

    init(
        selection: Binding<Int>,
        count: Int,
        peekWidth: CGFloat = 22,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._selection = selection
        self.count = count
        self.peekWidth = peekWidth
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let containerHeight = geo.size.height
            let cardWidth = max(0, containerWidth - 2 * (peekWidth + spacing))
            let stride = cardWidth + spacing
            let virtual = Double(selection) - Double(dragOffset) / Double(stride)

            HStack(spacing: spacing) {
                ForEach(0 ..< count, id: \.self) { i in
                    page(i, width: cardWidth, height: containerHeight)
                        .scaleEffect(reduceMotion ? 1.0 : scale(for: i, virtual: virtual))
                        .opacity(opacity(for: i, virtual: virtual))
                }
            }
            .frame(width: cardWidth * CGFloat(count) + spacing * CGFloat(max(0, count - 1)), alignment: .leading)
            .offset(x: (containerWidth - cardWidth) / 2 - CGFloat(selection) * stride + dragOffset)
            .contentShape(Rectangle())
            // simultaneousGesture (not gesture) so vertical drags can
            // also bubble up to an enclosing .sheet for swipe-down
            // dismissal AND to a nested NumberScrubber for vertical
            // value-scrubbing. The axis-claim inside `dragGesture`
            // gates the pager so it only acts on horizontally-
            // dominant drags — vertical scrubs pass through cleanly.
            .simultaneousGesture(dragGesture(stride: stride))
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: selection)
            // A programmatic page change while the user's finger is
            // down would otherwise yank the content out from under the
            // drag (offset is a function of `selection`). Re-baseline
            // so the visual position is unchanged and the drag keeps
            // tracking 1:1; the gesture's own settle logic then wins.
            .onChange(of: selection) { oldValue, newValue in
                guard isDragging else { return }
                let shift = CGFloat(newValue - oldValue) * stride
                dragBase += shift
                dragOffset += shift
            }
        }
    }

    /// Keep neighboring cards rendered as visual swipe cues while replacing
    /// their accessibility representation with an empty view. The explicit
    /// conditional is intentional: some accessibility runtimes continue to
    /// expose descendants when `accessibilityHidden` receives a changing
    /// Boolean on a transformed pager page.
    @ViewBuilder
    private func page(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        if index == selection {
            content(index)
                .frame(width: width, height: height)
        } else {
            content(index)
                .frame(width: width, height: height)
                .accessibilityRepresentation { EmptyView() }
                .accessibilityHidden(true)
        }
    }

    // MARK: - Gesture

    private func dragGesture(stride: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let tw = value.translation.width
                let th = value.translation.height

                // Decide the dominant axis on the first unambiguous
                // movement. The 8pt threshold filters out the tiny
                // jitter that can otherwise lock to the wrong axis
                // when a drag begins with a near-diagonal flick.
                if horizontalAxisLocked == nil {
                    let totalMag = max(abs(tw), abs(th))
                    guard totalMag >= 8 else { return }
                    horizontalAxisLocked = abs(tw) > abs(th)
                }

                // Vertical drag won the axis claim — yield. The
                // NumberScrubber (or any other nested vertical
                // gesture) is the rightful owner; SwipePager stays
                // still for the rest of this drag.
                guard horizontalAxisLocked == true else { return }

                if !isDragging {
                    isDragging = true
                    lastCrossedIndex = selection
                }
                let raw = dragBase + tw
                let damped = applyEdgeRubberBand(raw, stride: stride)
                dragOffset = damped

                // Edge haptic — fire once when the user starts pulling past a wall.
                let isAtLeftEdge = selection == 0 && raw > 0
                let isAtRightEdge = selection == count - 1 && raw < 0
                let atEdge = isAtLeftEdge || isAtRightEdge

                if atEdge, abs(raw) > 28, !didEdgeHaptic {
                    Haptics.rigid(playsSound: false)
                    didEdgeHaptic = true
                } else if !atEdge {
                    didEdgeHaptic = false
                }

                // Crossing haptic — when the effective focus changes frames.
                let effective = Double(selection) - Double(damped) / Double(stride)
                let frame = Int(effective.rounded())
                if frame != lastCrossedIndex, frame >= 0, frame < count {
                    Haptics.tick(playsSound: false)
                    lastCrossedIndex = frame
                }
            }
            .onEnded { value in
                let wasHorizontal = horizontalAxisLocked == true
                horizontalAxisLocked = nil
                isDragging = false

                // No-op if the drag was claimed by the vertical axis
                // (or never reached the decision threshold) — there's
                // nothing to settle. dragOffset was never touched.
                guard wasHorizontal else { return }

                let translated = Double(dragBase) + Double(value.translation.width)
                let predicted = Double(dragBase) + Double(value.predictedEndTranslation.width)
                let actual = Double(selection) - translated / Double(stride)
                let projected = Double(selection) - predicted / Double(stride)

                // Native paging physics: a deliberate drag can travel
                // any number of pages, but momentum carries at most
                // one page past where the finger actually released.
                // Unclamped, a brisk flick projects 2+ strides and
                // skips the neighboring card entirely.
                let anchor = Int(actual.rounded())
                let momentumTarget = Int(projected.rounded())
                let railed = max(anchor - 1, min(anchor + 1, momentumTarget))
                let target = max(0, min(count - 1, railed))

                let landed = target != selection
                dragBase = 0
                if reduceMotion {
                    selection = target
                    dragOffset = 0
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        selection = target
                        dragOffset = 0
                    }
                }
                if landed {
                    Haptics.soft(playsSound: false)
                }
                lastCrossedIndex = target
                didEdgeHaptic = false
            }
    }

    // MARK: - Rubber band

    private func applyEdgeRubberBand(_ raw: CGFloat, stride: CGFloat) -> CGFloat {
        let range = stride * 0.5
        if raw > 0, selection == 0 {
            return rubberBand(raw, range: range)
        }
        if raw < 0, selection == count - 1 {
            return -rubberBand(-raw, range: range)
        }
        return raw
    }

    /// Asymptotic decay — distance never exceeds `range`.
    private func rubberBand(_ x: CGFloat, range: CGFloat) -> CGFloat {
        range * (1 - exp(-x / range))
    }

    // MARK: - Peek styling

    private func scale(for index: Int, virtual: Double) -> CGFloat {
        let distance = min(1.0, abs(Double(index) - virtual))
        return CGFloat(1.0 - 0.08 * distance) // 1.00 → 0.92
    }

    private func opacity(for index: Int, virtual: Double) -> Double {
        let distance = min(1.0, abs(Double(index) - virtual))
        return 1.0 - 0.45 * distance // 1.00 → 0.55
    }
}

// MARK: - Page indicator

struct PageDots: View {
    let count: Int
    @Binding var selection: Int

    /// Index ranges whose pages form one superset group. Their dots
    /// render inside a single outlined capsule so the linked pages
    /// read as one station with segments, not separate exercises.
    var linkedRuns: [ClosedRange<Int>] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(clusters, id: \.self) { cluster in
                if cluster.count == 1 {
                    dot(cluster[0])
                } else {
                    HStack(spacing: 4) {
                        ForEach(cluster, id: \.self) { dot($0) }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .overlay(
                        Capsule().strokeBorder(Ink.quaternary, lineWidth: 1)
                    )
                }
            }
        }
        // The visible page indicator doubles as the semantic page control.
        // Keeping this separate from SwipePager's content preserves every
        // control on the selected card while still providing direct page
        // navigation for VoiceOver.
        .frame(minWidth: Space.tapMin, minHeight: Space.tapMin)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exercise pages")
        .accessibilityValue("Page \(selection + 1) of \(count)")
        .accessibilityHint("Double tap for the next page, or use the actions menu")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            guard count > 1 else { return }
            if selection < count - 1 {
                moveSelection(by: 1)
            } else {
                selection = 0
                Haptics.soft()
            }
        }
        .accessibilityAction(named: "Next exercise") {
            moveSelection(by: 1)
        }
        .accessibilityAction(named: "Previous exercise") {
            moveSelection(by: -1)
        }
    }

    private func moveSelection(by delta: Int) {
        let next = min(max(selection + delta, 0), max(0, count - 1))
        guard next != selection else {
            Haptics.rigid()
            return
        }
        selection = next
        Haptics.soft()
    }

    /// Page indices grouped for rendering: linked runs collapse into
    /// one multi-dot cluster, everything else stands alone.
    private var clusters: [[Int]] {
        var result: [[Int]] = []
        var i = 0
        while i < count {
            if let run = linkedRuns.first(where: { $0.lowerBound == i }),
               run.upperBound < count
            {
                result.append(Array(run))
                i = run.upperBound + 1
            } else {
                result.append([i])
                i += 1
            }
        }
        return result
    }

    private func dot(_ i: Int) -> some View {
        Capsule()
            .fill(i == selection ? Ink.primary : Ink.quaternary)
            .frame(width: i == selection ? 22 : 6, height: 6)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78), value: selection)
    }
}
