#if DEBUG
//
//  ConsistencyStripGallery.swift
//  vivobody
//
//  Step the training density up and down to see how the rolling strip
//  reads at every adherence level, from a dead fortnight to daily
//  training, with the record days pulsing.
//

import VivoKit
import SwiftUI

struct ConsistencyStripGallery: View {
    /// Trained days out of the last 14, spread evenly across them.
    @State private var trainedDays: Int = 6
    @State private var showsRecords: Bool = true

    private static let today = Calendar.current.startOfDay(for: Date())

    /// Evenly spaced offsets so each density reads as a training
    /// rhythm rather than a random scatter.
    private var offsets: [Int] {
        guard trainedDays > 0 else { return [] }
        let stride = 14.0 / Double(trainedDays)
        return (0..<trainedDays).map { Int((Double($0) * stride).rounded()) }
    }

    private var workoutDates: Set<Date> {
        Set(offsets.compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: Self.today)
        })
    }

    private var prDates: Set<Date> {
        guard showsRecords else { return [] }
        return Set(workoutDates.sorted().suffix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            header

            ConsistencyStrip(workoutDates: workoutDates, prDates: prDates)
                .padding(Space.xl)
                .contentCard()

            densityBar

            Toggle("Records", isOn: $showsRecords)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.secondary)
                .tint(Tint.primary)

            Spacer()
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.section)
        .padding(.bottom, Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONSISTENCY STRIP")
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Two weeks, one ember per day — trained, record, or rest")
                .font(Typography.body)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private var densityBar: some View {
        HStack(spacing: 0) {
            step(systemName: "minus") {
                trainedDays = max(0, trainedDays - 1)
            }
            Spacer()
            Text("\(trainedDays) of 14 days trained")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.secondary)
                .monospacedDigit()
            Spacer()
            step(systemName: "plus") {
                trainedDays = min(14, trainedDays + 1)
            }
        }
    }

    private func step(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            Image(systemName: systemName)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Gallery") {
    ConsistencyStripGallery()
        .preferredColorScheme(.dark)
}
#endif
