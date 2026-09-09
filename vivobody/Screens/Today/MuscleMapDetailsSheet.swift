//
//  MuscleMapDetailsSheet.swift
//  vivobody
//
//  Evidence behind Today's chronic 3D development colours. Muscles are
//  grouped by their coarse band, most developed first, with weekly
//  work and confidence kept as row metadata rather than encoded into
//  the body colour. Regions without a scene surface remain visible as
//  text instead of borrowing another anatomical mesh.
//

import SwiftUI
import VivoKit

struct MuscleMapDetailsSheet: View {
    let report: MuscleMapReport
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var entries: [MuscleMapEntry] {
        report.entries
            .sorted {
                if $0.channels.intensity == $1.channels.intensity {
                    return $0.muscle.displayName < $1.muscle.displayName
                }
                return $0.channels.intensity > $1.channels.intensity
            }
    }

    /// Bands that hold at least one muscle, most developed first.
    private var sections: [(band: MuscleDevelopmentBand, entries: [MuscleMapEntry])] {
        let grouped = Dictionary(grouping: entries, by: \.band)
        return MuscleDevelopmentBand.allCases.reversed().compactMap { band in
            grouped[band].map { (band: band, entries: $0) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Space.section) {
                    distributionCard
                    ForEach(sections, id: \.band.rawValue) { section in
                        bandSection(section.band, entries: section.entries)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.section)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Load-bearing: pins the scroll content to the viewport
                // width. Without it the content measures wider than the
                // sheet and the vertical-only ScrollView pans sideways.
                .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle("Current development")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Distribution

    private static let barHeight: CGFloat = 12
    private static let barGap: CGFloat = 2

    /// How the whole body splits across bands, in the same left-to-right
    /// order as Today's legend so the two surfaces read as one scale.
    private var distributionCard: some View {
        let counts = bandCounts
        let total = max(1, entries.count)
        return VStack(alignment: .leading, spacing: Space.md) {
            GeometryReader { proxy in
                let gaps = Self.barGap * CGFloat(max(0, counts.count - 1))
                let available = max(0, proxy.size.width - gaps)
                HStack(spacing: Self.barGap) {
                    ForEach(counts, id: \.band.rawValue) { item in
                        Rectangle()
                            .fill(color(for: item.band))
                            .frame(width: available * CGFloat(item.count) / CGFloat(total))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: Self.barHeight)

            distributionLegend
                .font(Typography.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .contentCard(bright: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(distributionAccessibilityLabel)
    }

    /// One wrapping line naming every segment, counts emphasised.
    private var distributionLegend: Text {
        bandCounts.enumerated().reduce(Text("")) { line, item in
            let (index, entry) = item
            let separator = index == 0 ? "" : "  ·  "
            return line
                + Text(separator).foregroundStyle(Ink.quaternary)
                + Text("\(entry.count) ").foregroundStyle(Ink.secondary).monospacedDigit()
                + Text(entry.band.displayName).foregroundStyle(Ink.tertiary)
        }
    }

    private var bandCounts: [(band: MuscleDevelopmentBand, count: Int)] {
        let grouped = Dictionary(grouping: entries, by: \.band)
        return MuscleDevelopmentBand.allCases.compactMap { band in
            grouped[band].map { (band: band, count: $0.count) }
        }
    }

    private var distributionAccessibilityLabel: String {
        let parts = bandCounts.map { "\($0.count) \($0.band.displayName.lowercased())" }
        return "Development across \(entries.count) muscles: " + parts.joined(separator: ", ")
    }

    // MARK: - Band sections

    private func bandSection(_ band: MuscleDevelopmentBand, entries: [MuscleMapEntry]) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: band.displayName,
                trailing: entries.count == 1 ? "1 muscle" : "\(entries.count) muscles"
            )

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    row(entry)
                    if index < entries.count - 1 {
                        rowDivider
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .contentCard()
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
    }

    private func row(_ entry: MuscleMapEntry) -> some View {
        HStack(alignment: .center, spacing: Space.md) {
            swatch(entry)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.muscle.displayName)
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                Text(detail(entry))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if !entry.topExercises.isEmpty {
                    Text(entry.topExercises.joined(separator: " · "))
                        .font(Typography.micro)
                        .foregroundStyle(Ink.quaternary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Space.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.band == .noData ? "—" : format(entry.effectiveSets14d))
                    .font(Typography.metricInline)
                    .foregroundStyle(entry.band == .noData ? Ink.quaternary : Ink.primary)
                    .monospacedDigit()
                Text("sets · 14d")
                    .panelLegend()
            }
            .fixedSize()
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(entry))
    }

    /// Solid colour for muscles the body renders; a hollow outline for
    /// regions with no scene surface, so the list still shows them.
    @ViewBuilder
    private func swatch(_ entry: MuscleMapEntry) -> some View {
        if entry.muscle.isVisualized {
            Capsule()
                .fill(color(for: entry.channels))
                .frame(width: 5, height: 28)
        } else {
            Capsule()
                .strokeBorder(Ink.quaternary, lineWidth: 1)
                .frame(width: 5, height: 28)
        }
    }

    private func detail(_ entry: MuscleMapEntry) -> String {
        var parts: [String] = []
        if entry.band == .noData {
            parts.append("No working-set history")
        } else {
            parts.append(entry.daysSinceLastTrained.map { "Trained \($0)d ago" } ?? "Last training unknown")
            parts.append(confidenceLabel(entry))
        }
        if !entry.muscle.isVisualized {
            parts.append("Not on 3D model")
        }
        return parts.joined(separator: " · ")
    }

    private func confidenceLabel(_ entry: MuscleMapEntry) -> String {
        switch entry.confidence {
        case .limited, nil: "Limited data"
        case .moderate: "Moderate confidence"
        case .high: "High confidence"
        }
    }

    private func accessibilityLabel(_ entry: MuscleMapEntry) -> String {
        var parts = ["\(entry.muscle.displayName), \(entry.band.displayName)"]
        if entry.band != .noData {
            parts.append("\(format(entry.effectiveSets14d)) effective sets in 14 days")
        }
        parts.append(detail(entry))
        if !entry.topExercises.isEmpty {
            parts.append(entry.topExercises.joined(separator: ", "))
        }
        return parts.joined(separator: ". ")
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    // MARK: - Colour

    private func color(for band: MuscleDevelopmentBand) -> Color {
        let channels = band == .noData
            ? MuscleMapChannels.noData
            : MuscleMapChannels(intensity: band.representativeIntensity)
        return color(for: channels)
    }

    private func color(for channels: MuscleMapChannels) -> Color {
        let rgb = MuscleColor.rgb(
            for: channels,
            theme: colorScheme == .dark ? .dark : .light
        )
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
