//
//  ExerciseDetailScreen.swift
//  vivobody
//
//  Drill-down view for an ExerciseCatalogItem. Reached by tapping
//  a row in the ExercisePickerSheet — replaces the previous "tap =
//  immediate pick" behavior with "tap = explore, then commit via
//  CTA at the bottom." Long-press on the picker row preserves the
//  quick Edit / Delete context menu.
//
//  Surfaces (when data exists):
//    • Hero    — muscle group accent + exercise name + metadata line,
//                plus a plateau / load-mode-aware readiness status pill
//    • Stats   — Last (top set + relative date), Best (standing record
//                under the exercise's performance semantics), Times
//    • 1RM     — Dedicated, tappable row (dynamic strength only): a user-measured
//                max (precise) overrides the estimated e1RM; empty
//                until there's data. Tap opens the scrubber editor.
//    • Rhythm  — median time between load increases + rhythm strip
//                (Pro, comparable-load lifts with ≥2 increases)
//    • Chart   — SwiftUI Charts line with PR dots + a Load | e1RM |
//                Volume metric toggle (reps only) + time-range chips
//    • Effort  — average RIR + progression verdict (dynamic strength
//                only, gated on having ≥3 logged RIR readings)
//    • Muscles — primary / secondary / stabilizer roles from the catalog map
//    • Recents — Last 5 sessions, top set + date + PR flag
//    • Defaults— The catalog item's starting weight × reps
//    • CTA     — "+ Add to Workout" pinned to the bottom safe area
//
//  Empty-state behavior: when the user has never logged this
//  exercise, the stats row shows em-dashes, the chart and recents
//  sections are hidden, and the rest of the screen still functions
//  (defaults, CTA, edit/delete).
//

import VivoKit
import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailScreen: View {
    /// The catalog item this screen is exploring. Held as a let —
    /// SwiftData @Model observation handles updates when the editor
    /// sheet mutates the underlying record.
    let item: ExerciseCatalogItem

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
    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    var bodyWeightEntries: [BodyWeightEntry]

    @AppStorage(SettingsKey.weightUnit)
    var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var currentBodyweight: Double {
        bodyWeightEntries.first(where: { $0.weight > 0 })?.weight
            ?? ExerciseLoad.unknownBodyweight
    }

    @State private var editorTarget: CatalogEditorTarget?
    @State private var isConfirmingDelete: Bool = false
    /// Local paywall presentation — this screen can live inside other
    /// sheets (Spotlight detail, exercise picker), where the app-root
    /// paywall sheet can't present on top.
    @State var isPaywallPresented: Bool = false
    @State var isEditingOneRepMax: Bool = false
    @State var range: TimeRange = .all
    @State var chartMetric: ChartMetric = .e1rm
    @State private var saveError: SaveErrorBox? = nil

    /// Number of consecutive stale sessions before the hero flags a
    /// plateau. Five matches the "a working block didn't move the
    /// needle" intuition — short enough to be actionable, long enough
    /// to ignore normal week-to-week noise.
    static let plateauThreshold = 5

    /// Which series the progress chart plots. Only offered for
    /// `.reps` exercises — timed holds always plot duration.
    enum ChartMetric: String, CaseIterable, Identifiable {
        case weight, e1rm, volume
        var id: String { rawValue }
        var label: String {
            switch self {
            case .weight: return "Load"
            case .e1rm:   return "e1RM"
            case .volume: return "Volume"
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
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneMonth:    return "1M"
            case .threeMonths: return "3M"
            case .sixMonths:   return "6M"
            case .all:         return "All"
            }
        }
        var cutoff: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth:    return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: Date())
            case .all:         return nil
            }
        }
    }

    let prColor = Tint.complete

    var body: some View {
        let _ = sessionAnalytics?.update(for: completedSessions)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                hero
                statsRow
                if supportsEstimatedOneRepMax {
                    oneRepMaxRow
                }
                progressionRhythmSection
                if hasHistory {
                    if pro?.isUnlocked == true {
                        chartSection
                    } else {
                        lockedChartSection
                    }
                }
                effortSection
                exerciseAnatomySection
                muscleBreakdownSection
                if hasHistory {
                    recentSessionsSection
                }
                defaultsSection
            }
            .padding(.top, 8)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .detailForgeBackground()
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editorTarget = .edit(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
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
            if onPickAndDismiss != nil {
                addToWorkoutCTA
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomExerciseEditorSheet(target: target)
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
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes the exercise from your catalog. Templates and history that already reference it stay intact.")
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - Mutations

    /// Remove the catalog item, save, then dismiss the screen — the
    /// picker's @Query will refresh and the row disappears. Templates
    /// and history are unaffected (they copy values at pick-time and
    /// never reference catalog items directly).
    private func deleteAndDismiss() {
        let id = item.id
        modelContext.delete(item)
        do {
            try modelContext.saveOrRollback()
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
