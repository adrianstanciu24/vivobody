#if DEBUG
//
//  SwipePagerGallery.swift
//  vivobody
//
//  Five placeholder "exercise cards" loaded into a SwipePager so the
//  interaction can be felt before any data model exists. Each card has
//  its own accent color so you can read the crossfade between neighbors.
//

import VivoKit
import SwiftUI

struct SwipePagerGallery: View {
    @State private var index: Int = 0

    private let exercises: [ExerciseSeed] = [
        .init(name: "BENCH PRESS",     scheme: "3 × 8",   group: "chest",      accent: Color(red: 0.78, green: 0.20, blue: 0.20)),
        .init(name: "OVERHEAD PRESS",  scheme: "3 × 8",   group: "shoulders",  accent: Color(red: 0.95, green: 0.62, blue: 0.22)),
        .init(name: "BARBELL ROW",     scheme: "3 × 8",   group: "back",       accent: Color(red: 0.22, green: 0.62, blue: 0.36)),
        .init(name: "PULL-UPS",        scheme: "3 × MAX", group: "back",       accent: Color(red: 0.32, green: 0.50, blue: 0.78)),
        .init(name: "FACE PULLS",      scheme: "3 × 12",  group: "rear delts", accent: Color(red: 0.62, green: 0.34, blue: 0.72)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            header

            SwipePager(selection: $index, count: exercises.count) { i in
                ExerciseCardPlaceholder(seed: exercises[i], index: i, total: exercises.count)
            }
            .frame(height: 420)

            PageDots(count: exercises.count, selection: index)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.section)
        .padding(.bottom, Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SWIPE PAGER")
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Move between exercises.")
                .font(Typography.display)
                .foregroundStyle(.white)
            Text("Drag horizontally. Flick for momentum. Neighbors peek so you always know what's next.")
                .font(Typography.sectionLabel)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Placeholder card

struct ExerciseSeed: Hashable {
    let name: String
    let scheme: String
    let group: String
    let accent: Color
}

struct ExerciseCardPlaceholder: View {
    let seed: ExerciseSeed
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: index + group
            HStack {
                Text(String(format: "%02d / %02d", index + 1, total))
                    .font(Typography.metricMicro)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(seed.group.uppercased())
                    .font(Typography.metricMicro)
                    .tracking(2)
                    .foregroundStyle(seed.accent)
            }

            Spacer()

            // Center: exercise name + accent line
            VStack(alignment: .leading, spacing: Space.lg) {
                Rectangle()
                    .fill(seed.accent)
                    .frame(width: 44, height: 2)

                Text(seed.name)
                    .font(Typography.display)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // Bottom: scheme
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(seed.scheme)
                    .font(Typography.statValue)
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(Typography.headline)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 6)
    }

    private var cardBackground: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.11)
            LinearGradient(
                colors: [seed.accent.opacity(0.22), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }
}

#Preview("Swipe Pager") {
    SwipePagerGallery()
        .preferredColorScheme(.dark)
}

#endif
