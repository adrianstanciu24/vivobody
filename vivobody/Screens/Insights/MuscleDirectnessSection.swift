//
//  MuscleDirectnessSection.swift
//  vivobody
//
//  Direct/indirect beams expose the role behind muscle volume. The headline
//  names the largest secondary-work recipient; full rosters, sources, and
//  authored primary-target examples are one navigation level away.
//

import SwiftData
import SwiftUI
import VivoKit

struct MuscleDirectnessSection: View {
    let report: MuscleDirectness
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink {
            MuscleDirectnessList(report: report)
        } label: {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack {
                    Text("Direct vs. indirect").font(Typography.title)
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.right").font(Typography.caption)
                }
                .foregroundStyle(Ink.primary)
                Text("Hard sets · all time").font(Typography.caption).foregroundStyle(Ink.secondary)
                if let top = report.passengers.first {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(top.muscle.displayName).font(Typography.title)
                            .foregroundStyle(Ink.primary)
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.sm))
                        layout {
                            Text("\(Int((top.indirectShare * 100).rounded()))%")
                                .font(Typography.statValue).foregroundStyle(Tint.primaryText)
                            Text("indirect").font(Typography.headline).foregroundStyle(Ink.secondary)
                        }
                    }
                    let rows = Array(report.passengers.prefix(dynamicTypeSize.isAccessibilitySize ? 1 : 3))
                    let scale = rows.map(\.total).max() ?? 1
                    MuscleRoleLegend()
                    ForEach(rows) { row in
                        MuscleRoleBeam(row: row, scale: scale, showsName: row.id != top.id)
                    }
                } else {
                    Text(report.trained.isEmpty ? "No muscle work recorded" : "All recorded work was direct")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                }
            }
            .padding(Space.xl).contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insightsMuscleDirectnessLink")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens every muscle, its secondary sources, and primary-target exercise examples")
    }

    private var accessibilityLabel: String {
        let rows = report.passengers.prefix(dynamicTypeSize.isAccessibilitySize ? 1 : 3).map { row in
            "\(row.muscle.displayName): \(InsightsFormat.setsLabel(row.direct)) direct, \(InsightsFormat.setsLabel(row.indirect)) indirect hard sets, \(Int((row.indirectShare * 100).rounded())) percent indirect."
        }.joined(separator: " ")
        return "Direct versus indirect. All time. \(rows.isEmpty ? "No secondary muscle work recorded." : rows)"
    }
}

private struct MuscleDirectnessList: View {
    let report: MuscleDirectness

    var body: some View {
        InsightsDrilloutScreen(title: "Direct vs. indirect") {
            LazyVStack(alignment: .leading, spacing: Space.lg) {
                Text("Hard sets · all time").panelLegend()
                MuscleRoleLegend()
                Text("Muscle work").font(Typography.title)
                    .accessibilityIdentifier("muscleDirectnessRoster").accessibilityAddTraits(.isHeader)
                ForEach(report.trained.sorted { $0.indirectShare > $1.indirectShare }) { row in
                    NavigationLink {
                        MuscleDirectnessDetail(row: row)
                    } label: {
                        MuscleRoleBeam(row: row, scale: report.trained.map(\.total).max() ?? 1)
                            .padding(Space.lg).contentCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("muscleDirectness-\(row.muscle.rawValue)")
                }
                DisclosureGroup("No recorded work") {
                    ForEach(report.rows.filter { $0.total == 0 }) { row in
                        NavigationLink {
                            MuscleDirectnessDetail(row: row)
                        } label: {
                            Text(row.muscle.displayName).font(Typography.body)
                                .frame(minHeight: 44)
                        }
                    }
                }
                .font(Typography.body).frame(minHeight: 44)
                DisclosureGroup("How roles earn credit") {
                    Text("A primary muscle receives full hard-set credit; a secondary muscle receives half. Logged effort adjusts both. Stabilizers receive none. These are credited hard sets, not a count of sets performed just for that muscle.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                        .padding(.top, Space.sm)
                }
                .font(Typography.body).frame(minHeight: 44)
            }
        }
    }
}

private struct MuscleDirectnessDetail: View {
    let row: MuscleDirectness.Row

    var body: some View {
        InsightsDrilloutScreen(title: row.muscle.displayName) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("Hard sets · all time").panelLegend()
                    MuscleRoleLegend()
                    MuscleRoleBeam(row: row, scale: max(1, row.total))
                }
                .padding(Space.xl).contentCard()
                if !row.sources.isEmpty {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("Riding along on").font(Typography.title).accessibilityAddTraits(.isHeader)
                        ForEach(row.sources) { source in
                            HStack(alignment: .firstTextBaseline) {
                                Text(source.name).font(Typography.body).foregroundStyle(Ink.secondary)
                                Spacer(minLength: Space.md)
                                Text(InsightsFormat.setsLabel(source.sets))
                                    .font(Typography.metricInline).monospacedDigit()
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(source.name), \(InsightsFormat.setsLabel(source.sets)) indirect hard sets")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Primary here").font(Typography.title)
                        .accessibilityIdentifier("musclePrimaryExamples").accessibilityAddTraits(.isHeader)
                    if row.examples.isEmpty {
                        Text("No primary-target example in the catalog.")
                            .font(Typography.body).foregroundStyle(Ink.secondary)
                    }
                    ForEach(row.examples) { example in
                        NavigationLink {
                            InsightsCatalogExerciseDestination(catalogID: example.id)
                        } label: {
                            HStack(spacing: Space.md) {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text(example.name).font(Typography.headline).foregroundStyle(Ink.primary)
                                    Text(example.equipment.displayName).font(Typography.caption).foregroundStyle(Ink.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(Ink.tertiary)
                            }
                            .frame(minHeight: 44).padding(Space.lg).contentCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct MuscleRoleLegend: View {
    var body: some View {
        InsightChartLegend(items: [
            .init(label: "Direct", color: Tint.primary, swatch: .fill),
            .init(label: "Indirect", color: Ink.secondary, swatch: .fill),
        ])
    }
}

private struct MuscleRoleBeam: View {
    let row: MuscleDirectness.Row
    let scale: Double
    var showsName = true

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if showsName {
                Text(row.muscle.displayName).font(Typography.headline).foregroundStyle(Ink.primary)
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Surface.cardTintBright)
                    HStack(spacing: 0) {
                        Rectangle().fill(Tint.primary).frame(width: width * row.direct / max(1, scale))
                        Rectangle().fill(Ink.secondary).frame(width: width * row.indirect / max(1, scale))
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 16)
            HStack {
                Text("\(InsightsFormat.setsLabel(row.direct)) direct")
                Spacer(minLength: Space.sm)
                Text("\(InsightsFormat.setsLabel(row.indirect)) indirect")
            }
            .font(Typography.caption).monospacedDigit().foregroundStyle(Ink.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.muscle.displayName), \(InsightsFormat.setsLabel(row.direct)) direct and \(InsightsFormat.setsLabel(row.indirect)) indirect hard sets, all time")
    }
}

private struct InsightsCatalogExerciseDestination: View {
    @Query private var items: [ExerciseCatalogItem]

    init(catalogID: String) {
        var descriptor = FetchDescriptor<ExerciseCatalogItem>(
            predicate: #Predicate { $0.catalogID == catalogID }
        )
        descriptor.fetchLimit = 1
        _items = Query(descriptor)
    }

    var body: some View {
        if let item = items.first {
            ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
        } else {
            ContentUnavailableView("Exercise unavailable", systemImage: "dumbbell")
        }
    }
}
