//
//  ExerciseDetailScreen.swift
//  vivobody
//
//  Drill-down view for an ExerciseCatalogItem. Reached by tapping
//  a row in the ExercisePickerSheet — replaces the previous "tap =
//  immediate pick" behavior with "tap = explore, then commit via
//  CTA at the bottom." Long-press on the picker row preserves the
//  quick Edit / Duplicate / Delete context menu. The toolbar menu
//  here offers the same actions, with "Duplicate as Custom" limited
//  to bundled exercises (a custom entry is already fully editable).
//  Comparison is entered through the "Compare with another exercise"
//  row beside the how-to drill-out (or the toolbar menu) and is
//  Pro-gated at that entry: free users get the local paywall, Pro
//  users get a "Compare With" picker that chains into the
//  ExerciseComparisonScreen sheet. The active-workout add host
//  suppresses that entry entirely so logging never opens comparison
//  or a premium interruption mid-session.
//
//  Surfaces (when data exists):
//    • Hero    — orange modality eyebrow + exercise name, plus a
//                plateau / load-mode-aware readiness status pill;
//                the inline nav title stays hidden until this scrolls off
//    • Figure  — the staged anatomy model in a card under the hero text;
//                primary/secondary/stabilizer roles use distinct visual
//                intensities without changing development calculations
//    • Movement — how the lift moves: a cardinal-plane glyph with the
//                active planes lit beside pattern / mechanic / planes /
//                laterality rows; absorbs the classification facts the
//                hero meta line once carried (now equipment-only)
//    • Steps   — a dedicated, numbered how-to screen built from the
//                catalog's authored movement instructions
//    • Stats   — a focal Best-set card (huge monospaced record numeral)
//                with a sessions / per-week / last-performed frequency
//                footer behind a hairline
//    • Load    — Bodyweight/assistance-only effective-load breakdown,
//                using the historical workout snapshot behind the record
//    • 1RM     — Dedicated, tappable tested-max row (dynamic strength
//                only). Estimated strength belongs to the trend curve;
//                this row stays an explicit user-entered measurement.
//    • Week    — per-muscle hard-set contribution over the trailing 7
//                days against each muscle's weekly band (Pro)
//    • Rhythm  — median time between load increases + rhythm strip
//                (Pro, comparable-load lifts with ≥2 increases)
//    • Chart   — a bold estimated-strength trend instrument (including
//                its four-workout build-up state), plus Load / Volume
//                history modes, range chips, PR dots, and endpoint values
//    • Effort  — average RIR + progression verdict (dynamic strength
//                only, gated on having ≥3 logged RIR readings)
//    • Recents — Last 5 sessions, top set + date + PR flag
//    • CTA     — "+ Add to Workout" pinned to the bottom safe area
//    • Unlock  — Insights-style floating Pro pill in the bottom bar
//                while any Pro-gated section above is frozen
//
//  Empty-state behavior: when the user has never logged this
//  exercise, the stats row shows em-dashes while an eligible strength
//  exercise still shows the dormant trend card so the user can see what
//  their next workouts will unlock. Other history sections stay hidden.
//  The rest of the screen still functions (CTA, edit/duplicate/delete).
//

import Charts
import SwiftData
import SwiftUI
import VivoKit

struct ExerciseDetailScreen: View {
    /// The catalog item this screen is exploring. Held as a let —
    /// SwiftData @Model observation handles updates when the editor
    /// sheet mutates the underlying record.
    let item: ExerciseCatalogItem

    /// False only when this detail is hosted by the active-workout
    /// add flow. Comparison is long-form catalog exploration and can
    /// surface a Pro gate, so it stays outside the live session.
    let allowsComparison: Bool

    /// Bundles the picker's `onPick(item)` + its own `dismiss()` into
    /// a single closure. Nil hides the bottom CTA entirely — useful
    /// when the detail is reached from a non-picking context (future
    /// surfaces like a standalone "Library" tab).
    let onPickAndDismiss: ((ExerciseCatalogItem) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sessionAnalytics) var sessionAnalytics

    /// Pro entitlement, injected by AppRoot. Optional so previews
    /// (which don't inject it) still build — nil renders unlocked.
    /// Gates the progress chart; the numeric stats stay free.
    @Environment(ProStore.self) var pro: ProStore?

    /// All archived sessions — drives progress chart + last-used +
    /// total-count + recent table. Same filter as the picker; live
    /// in-flight sessions never contribute.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    var completedSessions: [WorkoutSession]

    /// Current bodyweight is used only for an unlogged catalog default.
    /// Historical points carry their own session snapshots.
    @Query
    var bodyWeightEntries: [BodyWeightEntry]

    @AppStorage(SettingsKey.weightUnit)
    var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    var currentBodyweight: Double {
        bodyWeightEntries.first?.weight
            ?? ExerciseLoad.unknownBodyweight
    }

    /// Only bundled exercises offer duplication — a custom entry is
    /// already fully editable in place.
    private var canDuplicateAsCustom: Bool {
        item.catalogID != nil && !item.isUserCreated
    }

    init(
        item: ExerciseCatalogItem,
        allowsComparison: Bool = true,
        onPickAndDismiss: ((ExerciseCatalogItem) -> Void)?
    ) {
        self.item = item
        self.allowsComparison = allowsComparison
        self.onPickAndDismiss = onPickAndDismiss

        var latestBodyweight = FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.weight > 0 },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        latestBodyweight.fetchLimit = 1
        _bodyWeightEntries = Query(latestBodyweight)
    }

    @State private var editorTarget: CatalogEditorTarget?
    @State private var isConfirmingDelete: Bool = false
    /// Comparison flow state: the "Compare With" picker, the row the
    /// user tapped there, and the picked target once the picker sheet
    /// has fully dismissed (chained in `onDismiss` so the comparison
    /// sheet never presents over a dismissing sheet).
    @State private var isPickingComparison: Bool = false
    @State private var pendingComparisonTarget: ExerciseCatalogItem? = nil
    @State private var comparisonTarget: ExerciseCatalogItem? = nil
    /// Local paywall presentation — this screen can live inside other
    /// sheets (Spotlight detail, exercise picker), where the app-root
    /// paywall sheet can't present on top.
    @State var isPaywallPresented: Bool = false
    @State var isEditingOneRepMax: Bool = false
    @State var range: TimeRange = .all
    @State var chartMetric: ChartMetric = .e1rm
    @State private var saveError: SaveErrorBox? = nil
    /// Drives the inline nav title's fade: the hero owns the name at
    /// rest, so the bar only claims it once the hero has scrolled under.
    @State private var showsInlineTitle: Bool = false

    /// Number of consecutive stale sessions before the hero flags a
    /// plateau. Five matches the "a working block didn't move the
    /// needle" intuition — short enough to be actionable, long enough
    /// to ignore normal week-to-week noise.
    static let plateauThreshold = 5

    /// Which series the progress chart plots. Only offered for
    /// `.reps` exercises — timed holds always plot duration.
    enum ChartMetric: String, CaseIterable, Identifiable {
        case weight, e1rm, volume, reps
        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .weight: "Load"
            case .e1rm: "e1RM"
            case .volume: "Volume"
            case .reps: "Reps"
            }
        }
    }

    /// Chart time-range chips. Same enum-shape as
    /// ExerciseProgressDetail.TimeRange — kept private to this screen
    /// because the two screens have separate lifecycles (and the
    /// shared shape isn't reused in a meaningful enough way yet to
    /// justify hoisting it out).
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths, all
        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .oneMonth: "1M"
            case .threeMonths: "3M"
            case .sixMonths: "6M"
            case .all: "All"
            }
        }

        var cutoff: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth: return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .sixMonths: return cal.date(byAdding: .month, value: -6, to: Date())
            case .all: return nil
            }
        }
    }

    let prColor = Tint.complete

    var body: some View {
        let analyticsRequest = sessionAnalytics?.requestKey(
            for: completedSessions
        )
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                hero
                heroFigureSection
                movementSection
                instructionsLink
                if allowsComparison {
                    compareLink
                }
                bestHeroCard
                if showsPerformanceRows {
                    performanceRows
                }
                weeklyVolumeSection
                if hasHistory || supportsEstimatedOneRepMax {
                    if pro?.isUnlocked ?? true {
                        chartSection
                    } else {
                        lockedChartSection
                    }
                }
                progressionRhythmSection
                effortSection
                if hasHistory {
                    recentSessionsSection
                }
            }
            .padding(.top, 8)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Keep intrinsically wide detail sections from expanding the
            // scroll content and turning this vertical screen into a
            // horizontally pannable canvas.
            .containerRelativeFrame(.horizontal)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { $0.contentOffset.y + $0.contentInsets.top }
        ) { _, offset in
            let show = offset > 56
            guard show != showsInlineTitle else { return }
            withAnimation(.smooth(duration: 0.2)) {
                showsInlineTitle = show
            }
        }
        .task(id: analyticsRequest) {
            sessionAnalytics?.requestCore(for: completedSessions)
        }
        .screenBackground()
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(item.name)
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .opacity(showsInlineTitle ? 1 : 0)
                    .accessibilityHidden(!showsInlineTitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(Typography.headline)
                        .foregroundStyle(item.isFavorite ? Tint.complete : Ink.secondary)
                }
                .accessibilityLabel(item.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if allowsComparison {
                        Button {
                            startComparison()
                        } label: {
                            Label(
                                "Compare with Another Exercise",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }
                    }
                    Button {
                        editorTarget = .edit(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if canDuplicateAsCustom {
                        Button {
                            editorTarget = .duplicate(item)
                        } label: {
                            Label("Duplicate as Custom", systemImage: "plus.square.on.square")
                        }
                    }
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(Typography.headline)
                }
                .accessibilityLabel("More options")
            }
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                if showsUnlockControl {
                    unlockProControl
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                }
                if onPickAndDismiss != nil {
                    addToWorkoutCTA
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomExerciseEditorSheet(target: target)
        }
        .sheet(
            isPresented: $isPickingComparison,
            onDismiss: openComparisonIfPicked
        ) {
            ExercisePickerSheet(
                purpose: .compare(anchorID: item.id, anchorName: item.name),
                onPick: { picked in
                    pendingComparisonTarget = picked
                }
            )
        }
        .sheet(item: $comparisonTarget) { other in
            NavigationStack {
                ExerciseComparisonScreen(anchor: item, other: other)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPaywallPresented) {
            if let pro {
                PaywallSheet(pro: pro)
            }
        }
        .sheet(isPresented: $isEditingOneRepMax) {
            OneRepMaxEditorSheet(
                initialValue: oneRepMaxSeed,
                hasMeasured: item.oneRepMax != nil,
                hasEstimate: estimatedOneRepMax != nil,
                onSave: { newValue in
                    item.oneRepMax = newValue.flatMap { value in
                        value.isFinite && value > 0 ? value : nil
                    }
                    do {
                        try modelContext.saveOrRollback()
                    } catch {
                        saveError = SaveErrorBox(error)
                    }
                }
            )
        }
        .alert(
            "Delete \"\(item.name)\"?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) {
                deleteAndDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the exercise from your catalog. Templates and history that already reference it stay intact.")
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - Mutations

    /// Entry to the Pro comparison flow. Free users get this screen's
    /// local paywall sheet (the app-root sheet can't present over the
    /// picker/Spotlight sheets this screen can live inside); Pro users
    /// go straight to the "Compare With" picker. Called from both the
    /// toolbar menu and the `compareLink` row (which lives in
    /// ExerciseComparisonScreen.swift), so it stays internal.
    func startComparison() {
        guard allowsComparison else { return }
        Haptics.soft()
        if pro?.isUnlocked ?? true {
            isPickingComparison = true
        } else {
            isPaywallPresented = true
        }
    }

    /// The picker dismissed: a picked row chains into the comparison
    /// sheet, a cancel leaves no trace.
    private func openComparisonIfPicked() {
        guard let pendingComparisonTarget else { return }
        comparisonTarget = pendingComparisonTarget
        self.pendingComparisonTarget = nil
    }

    private func toggleFavorite() {
        item.isFavorite.toggle()
        do {
            try modelContext.saveOrRollback()
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.tick()
    }

    /// Remove the catalog item, save, then dismiss the screen — the
    /// picker's @Query will refresh and the row disappears. Templates
    /// and history are unaffected (they copy values at pick-time and
    /// never reference catalog items directly).
    private func deleteAndDismiss() {
        do {
            let id = try ExerciseCatalogItem.deleteFromCatalog(item, in: modelContext)
            SpotlightIndexer.removeExercise(id: id)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.thunk()
        dismiss()
    }

    // MARK: - Formatters

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
