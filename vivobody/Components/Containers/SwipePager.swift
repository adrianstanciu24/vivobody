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
            let W = geo.size.width
            let H = geo.size.height
            let cardWidth = max(0, W - 2 * (peekWidth + spacing))
            let stride = cardWidth + spacing
            let virtual = Double(selection) - Double(dragOffset) / Double(stride)

            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    content(i)
                        .frame(width: cardWidth, height: H)
                        .scaleEffect(reduceMotion ? 1.0 : scale(for: i, virtual: virtual))
                        .opacity(opacity(for: i, virtual: virtual))
                }
            }
            .frame(width: cardWidth * CGFloat(count) + spacing * CGFloat(max(0, count - 1)), alignment: .leading)
            .offset(x: (W - cardWidth) / 2 - CGFloat(selection) * stride + dragOffset)
            .contentShape(Rectangle())
            // simultaneousGesture (not gesture) so vertical drags can
            // also bubble up to an enclosing .sheet for swipe-down
            // dismissal AND to a nested NumberScrubber for vertical
            // value-scrubbing. The axis-claim inside `dragGesture`
            // gates the pager so it only acts on horizontally-
            // dominant drags — vertical scrubs pass through cleanly.
            .simultaneousGesture(dragGesture(stride: stride))
            .accessibilityAction(named: "Next exercise") {
                guard selection < count - 1 else { return }
                selection += 1
                Haptics.soft()
            }
            .accessibilityAction(named: "Previous exercise") {
                guard selection > 0 else { return }
                selection -= 1
                Haptics.soft()
            }
            .focusable()
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: selection)
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
                let raw = tw
                let damped = applyEdgeRubberBand(raw, stride: stride)
                dragOffset = damped

                // Edge haptic — fire once when the user starts pulling past a wall.
                let isAtLeftEdge = selection == 0 && raw > 0
                let isAtRightEdge = selection == count - 1 && raw < 0
                let atEdge = isAtLeftEdge || isAtRightEdge

                if atEdge && abs(raw) > 28 && !didEdgeHaptic {
                    Haptics.rigid()
                    didEdgeHaptic = true
                } else if !atEdge {
                    didEdgeHaptic = false
                }

                // Crossing haptic — when the effective focus changes frames.
                let effective = Double(selection) - Double(damped) / Double(stride)
                let frame = Int(effective.rounded())
                if frame != lastCrossedIndex && frame >= 0 && frame < count {
                    Haptics.tick()
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

                let predicted = value.predictedEndTranslation.width
                let projected = Double(selection) - Double(predicted) / Double(stride)
                let target = max(0, min(count - 1, Int(projected.rounded())))

                let landed = target != selection
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
                    Haptics.soft()
                }
                lastCrossedIndex = target
                didEdgeHaptic = false
            }
    }

    // MARK: - Rubber band

    private func applyEdgeRubberBand(_ raw: CGFloat, stride: CGFloat) -> CGFloat {
        let range = stride * 0.5
        if raw > 0 && selection == 0 {
            return rubberBand(raw, range: range)
        }
        if raw < 0 && selection == count - 1 {
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
        return CGFloat(1.0 - 0.08 * distance)   // 1.00 → 0.92
    }

    private func opacity(for index: Int, virtual: Double) -> Double {
        let distance = min(1.0, abs(Double(index) - virtual))
        return 1.0 - 0.45 * distance            // 1.00 → 0.55
    }
}

// MARK: - Page indicator

struct PageDots: View {
    let count: Int
    let selection: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == selection ? Ink.primary : Ink.quaternary)
                    .frame(width: i == selection ? 22 : 6, height: 6)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78), value: selection)
            }
        }
        .accessibilityHidden(true)
    }
}
