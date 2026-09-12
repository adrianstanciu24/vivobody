//
//  MuscleDirectnessSection.swift
//  vivobody
//
//  Targeted/supporting shares explain how each muscle was trained. The preview
//  leads with intentional work; full rosters, sources, and
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
                    Text("How muscles are trained").font(Typography.title)
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.right").font(Typography.caption)
                }
                .foregroundStyle(Ink.primary)
                Text("All time").font(Typography.caption).foregroundStyle(Ink.secondary)
                let rows = Array(report.ranked.prefix(dynamicTypeSize.isAccessibilitySize ? 1 : 3))
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: Space.section) {
                        ForEach(rows) { row in
                            MuscleRoleBeam(row: row)
                        }
                    }
                } else {
                    Text("No muscle work recorded")
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
        .accessibilityHint("Opens every muscle, contributing exercises, and targeted exercise examples")
    }

    private var accessibilityLabel: String {
        let rows = report.ranked.prefix(dynamicTypeSize.isAccessibilitySize ? 1 : 3).map { row in
            "\(row.muscle.displayName): \(roleSummary(row))."
        }.joined(separator: " ")
        return "How muscles are trained. All time. \(rows.isEmpty ? "No muscle work recorded." : rows)"
    }
}

private struct MuscleDirectnessList: View {
    let report: MuscleDirectness

    var body: some View {
        InsightsDrilloutScreen(title: "How muscles are trained") {
            LazyVStack(alignment: .leading, spacing: Space.lg) {
                Text("All time").panelLegend()
                Text("Muscle work").font(Typography.title)
                    .accessibilityIdentifier("muscleDirectnessRoster").accessibilityAddTraits(.isHeader)
                if !report.targeted.isEmpty {
                    Text("Targeted work").font(Typography.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(report.targeted) { row in
                        rowLink(row)
                    }
                }
                if !report.supportingOnly.isEmpty {
                    Text("Supporting work only").font(Typography.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(report.supportingOnly) { row in
                        rowLink(row)
                    }
                }
            }
        }
    }

    private func rowLink(_ row: MuscleDirectness.Row) -> some View {
        NavigationLink {
            MuscleDirectnessDetail(row: row)
        } label: {
            MuscleRoleBeam(row: row)
                .padding(Space.lg).contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("muscleDirectness-\(row.muscle.rawValue)")
    }
}

private struct MuscleDirectnessDetail: View {
    let row: MuscleDirectness.Row

    var body: some View {
        InsightsDrilloutScreen(title: row.muscle.displayName) {
            VStack(alignment: .leading, spacing: Space.xxl) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("All time").panelLegend()
                    MuscleRoleBeam(row: row)
                }
                .padding(Space.xl).contentCard()
                if !row.targetedSources.isEmpty {
                    ExerciseSourceBreakdown(
                        title: "Targeted exercises",
                        caption: "Breakdown of \(targetedPercentage)% targeted work",
                        sources: row.targetedSources,
                        total: row.direct,
                        tint: Tint.primary,
                        roleLabel: "targeted work"
                    )
                }
                if !row.supportingSources.isEmpty {
                    ExerciseSourceBreakdown(
                        title: "Supporting exercises",
                        caption: "Breakdown of \(supportingPercentage)% supporting work",
                        sources: row.supportingSources,
                        total: row.indirect,
                        tint: Ink.secondary,
                        roleLabel: "supporting work"
                    )
                }
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Targeted exercise examples").font(Typography.title)
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

    private var supportingPercentage: Int {
        Int((row.indirectShare * 100).rounded())
    }

    private var targetedPercentage: Int {
        100 - supportingPercentage
    }
}

private struct ExerciseSourceBreakdown: View {
    let title: String
    let caption: String
    let sources: [MuscleDirectness.Source]
    let total: Double
    let tint: Color
    let roleLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(Typography.title).accessibilityAddTraits(.isHeader)
                Text(caption).font(Typography.caption).foregroundStyle(Ink.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sources) { source in
                    ExerciseSourceShareRow(
                        source: source, total: total, tint: tint, roleLabel: roleLabel
                    )
                    if source.id != sources.last?.id {
                        SectionDivider().padding(.vertical, Space.lg)
                    }
                }
            }
            .padding(Space.xl).contentCard()
        }
    }
}

private struct ExerciseSourceShareRow: View {
    let source: MuscleDirectness.Source
    let total: Double
    let tint: Color
    let roleLabel: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var share: Double {
        total > 0 ? min(1, max(0, source.sets / total)) : 0
    }

    private var percentage: Int {
        Int((share * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.md))
            layout {
                Text(source.name)
                    .font(Typography.headline).foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text("\(percentage)%")
                    .font(Typography.statValueCompact).foregroundStyle(tint)
                    .monospacedDigit().fixedSize()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Surface.edge)
                    Capsule().fill(tint.gradient)
                        .frame(width: proxy.size.width * share)
                }
            }
            .frame(height: InstrumentBarHeight.micro)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(source.name), \(percentage) percent of \(roleLabel)")
    }
}

private func roleSummary(_ row: MuscleDirectness.Row) -> String {
    guard row.total > 0 else { return "No recorded work" }
    if row.direct == 0 { return "Supporting work only" }
    if row.indirect == 0 { return "Targeted work only" }
    let supporting = Int((row.indirectShare * 100).rounded())
    return "\(100 - supporting)% targeted · \(supporting)% supporting"
}

private struct MuscleRoleBeam: View {
    let row: MuscleDirectness.Row
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(row.muscle.displayName)
                .font(Typography.headline).foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            if row.total > 0 {
                if row.direct == 0 || row.indirect == 0 {
                    Text(roleSummary(row))
                        .font(Typography.headline)
                        .foregroundStyle(row.direct == 0 ? Ink.secondary : Tint.primary)
                } else {
                    let supporting = Int((row.indirectShare * 100).rounded())
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.sm))
                    layout {
                        Text("\(100 - supporting)% targeted").foregroundStyle(Tint.primary)
                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                        Text("\(supporting)% supporting").foregroundStyle(Ink.secondary)
                    }
                    .font(Typography.headline).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                }
                GeometryReader { proxy in
                    let share = 1 - row.indirectShare
                    let gap: CGFloat = share > 0 && share < 1 ? 3 : 0
                    let width = max(0, proxy.size.width - gap)
                    HStack(spacing: gap) {
                        if share > 0 {
                            Capsule().fill(Tint.primary.gradient)
                                .frame(width: width * share)
                        }
                        if share < 1 {
                            Capsule().fill(Ink.secondary.opacity(0.6))
                                .frame(width: width * (1 - share))
                        }
                    }
                }
                .frame(height: InstrumentBarHeight.standard)
            } else {
                Text("No recorded work").font(Typography.caption).foregroundStyle(Ink.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.muscle.displayName), \(roleSummary(row)), all time")
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
