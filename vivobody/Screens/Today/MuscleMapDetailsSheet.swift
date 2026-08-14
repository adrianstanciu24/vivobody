//
//  MuscleMapDetailsSheet.swift
//  vivobody
//
//  Evidence behind Today's chronic 3D development colours. Bands are
//  intentionally coarse, while weekly work and confidence stay visible
//  as separate metadata rather than being encoded into the body colour.
//  Regions without a scene surface remain visible as text instead of
//  borrowing another anatomical mesh.
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("A current estimate from completed strength sets, muscle roles, effort, and recency. Colour builds with repeated work and fades as training recedes. Power work does not add development credit.")
                        .font(Typography.body)
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Regions without a matching body-model surface remain listed and are marked 3D unavailable.")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.sm)
                        .padding(.bottom, Space.lg)

                    ForEach(entries) { entry in
                        row(entry)
                        SectionDivider()
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.lg)
            }
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
    }

    private func row(_ entry: MuscleMapEntry) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            if entry.muscle.isVisualized {
                Circle()
                    .fill(color(for: entry.channels))
                    .frame(width: 16, height: 16)
                    .padding(.top, 4)
            } else {
                Circle()
                    .strokeBorder(Ink.quaternary, lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.muscle.displayName)
                        .font(Typography.body)
                        .foregroundStyle(Ink.primary)
                    Spacer()
                    Text(entry.band.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.secondary)
                }

                Text(detail(entry))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if !entry.muscle.isVisualized {
                    Text("3D view unavailable")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }

                if !entry.topExercises.isEmpty {
                    Text(entry.topExercises.joined(separator: " · "))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ entry: MuscleMapEntry) -> String {
        guard entry.band != .noData else { return "No qualifying working-set history" }
        let sets = String(format: "%.1f effective sets · 7 days", entry.effectiveSets7d)
        let recency = entry.daysSinceLastTrained.map { "last trained \($0)d ago" } ?? "last trained unknown"
        let confidence = switch entry.confidence {
        case .limited, nil: "Limited data"
        case .moderate: "Moderate confidence"
        case .high: "High confidence"
        }
        return "\(sets) · \(recency) · \(confidence)"
    }

    private func color(for channels: MuscleMapChannels) -> Color {
        let rgb = MuscleColor.rgb(
            for: channels,
            theme: colorScheme == .dark ? .dark : .light
        )
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
