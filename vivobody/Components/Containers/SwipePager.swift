//
//  SwipePager.swift
//  vivobody
//
//  Horizontal pager with a center-locked active card and a peek of the
//  neighbors on each side — the Stories-style interaction, applied to
//  workout exercises. A native paging ScrollView supplies the drag,
//  momentum, and edge bounce. The pager adds the neighbor styling,
//  selection sync, and haptics: a tick when the focus crosses into a new
//  card, a soft tap when a swipe lands, and a rigid bump at the walls.
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

extension EnvironmentValues {
    /// Set inside SwipePager so nested scrubbers let its horizontal scroll
    /// recognize alongside their touch-down drags. Elsewhere scrubbers keep
    /// exclusive drags, so an enclosing vertical scroll view or form cannot
    /// move during a scrub.
    @Entry var scrubberSharesDrags = false
}

struct SwipePager<Content: View>: View {
    @Binding var selection: Int
    let count: Int
    let content: (Int) -> Content

    var peekWidth: CGFloat = 22
    var spacing: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled = SettingsDefaults.hapticsEnabled

    /// The page under the scroll view's center. It tracks the finger live;
    /// `selection` follows it only when a user scroll comes to rest, so the
    /// session sees one page change per swipe, as before.
    @State private var scrolledIndex: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var userScrolled = false
    @State private var crossings = 0
    @State private var landings = 0
    @State private var edgeBumps = 0

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
        self._scrolledIndex = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        GeometryReader { geo in
            let inset = peekWidth + spacing
            let cardWidth = max(0, geo.size.width - 2 * inset)
            let haptics = hapticsEnabled

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(0 ..< count, id: \.self) { i in
                            page(i, width: cardWidth, height: geo.size.height)
                        }
                    }
                    .scrollTargetLayout()
                }
                // The initial scroll position is ignored when the first layout
                // has no width yet, so place the selected page once it does.
                .onScrollGeometryChange(for: CGFloat.self, of: \.containerSize.width) { oldWidth, newWidth in
                    guard newWidth > 0, newWidth != oldWidth, !isUserScrolling else { return }
                    proxy.scrollTo(selection, anchor: .center)
                }
                .onAppear {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
            .contentMargins(.horizontal, inset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $scrolledIndex, anchor: .center)
            .scrollIndicators(.hidden)
            // Card shadows and scaled neighbors extend past the scroll bounds.
            .scrollClipDisabled()
            .environment(\.scrubberSharesDrags, true)
            .onScrollPhaseChange { _, phase in
                handleScrollPhase(phase)
            }
            .onScrollGeometryChange(for: Bool.self, of: { geometry in
                // Native rubber-banding moves the content about half as far
                // as the finger, so 16pt here matches the old 28pt pull.
                let x = geometry.contentOffset.x
                let leadingRest = -geometry.contentInsets.leading
                let trailingRest = geometry.contentSize.width
                    + geometry.contentInsets.trailing
                    - geometry.containerSize.width
                return x < leadingRest - 16 || x > trailingRest + 16
            }) { _, isPastEdge in
                if isPastEdge, scrollPhase == .interacting {
                    edgeBumps += 1
                }
            }
            .onChange(of: scrolledIndex) { _, _ in
                if isUserScrolling { crossings += 1 }
            }
            .onChange(of: selection) { _, newValue in
                follow(newValue)
            }
            .sensoryFeedback(trigger: crossings) { _, _ in
                haptics ? .impact(weight: .light, intensity: 0.6) : nil
            }
            .sensoryFeedback(trigger: landings) { _, _ in
                haptics ? .impact(flexibility: .soft) : nil
            }
            .sensoryFeedback(trigger: edgeBumps) { _, _ in
                haptics ? .impact(flexibility: .rigid) : nil
            }
        }
    }

    /// Keep every page mounted so its local interaction and entrance state
    /// survives selection changes. Collapse and hide neighboring semantics so
    /// only the selected page participates in accessibility.
    private func page(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        let scalesNeighbors = !reduceMotion
        return content(index)
            .frame(width: width, height: height)
            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                let distance = min(1, abs(phase.value))
                return effect
                    .scaleEffect(scalesNeighbors ? CGFloat(1 - 0.08 * distance) : 1)
                    .opacity(1 - 0.45 * distance)
            }
            // Collapsing an off-screen page before hiding it prevents SwiftUI
            // from leaking its transformed descendants into the accessibility
            // tree while preserving the rendered card's structural identity.
            .accessibilityElement(children: index == selection ? .contain : .ignore)
            .accessibilityHidden(index != selection)
    }

    private var isUserScrolling: Bool {
        scrollPhase == .interacting || scrollPhase == .decelerating
    }

    // MARK: - Selection sync

    private func handleScrollPhase(_ phase: ScrollPhase) {
        scrollPhase = phase
        if phase == .interacting { userScrolled = true }
        guard phase == .idle else { return }
        let landedFromUserScroll = userScrolled
        userScrolled = false
        guard landedFromUserScroll, let landed = scrolledIndex else {
            follow(selection)
            return
        }
        if landed != selection {
            selection = landed
            landings += 1
        }
    }

    /// Scroll to an externally written selection (page dots, superset
    /// auto-advance). A user scroll in flight keeps the position: its landing
    /// commits the page the finger chose, as the old drag re-baseline did.
    private func follow(_ index: Int) {
        guard !isUserScrolling, scrolledIndex != index else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
            scrolledIndex = index
        }
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
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: selection)
    }
}
