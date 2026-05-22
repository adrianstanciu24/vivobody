//
//  SwipePagerGallery.swift
//  workapp
//
//  Five placeholder "exercise cards" loaded into a SwipePager so the
//  interaction can be felt before any data model exists. Each card has
//  its own accent color so you can read the crossfade between neighbors.
//

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
        VStack(alignment: .leading, spacing: 22) {
            header

            SwipePager(selection: $index, count: exercises.count) { i in
                ExerciseCardPlaceholder(seed: exercises[i], index: i, total: exercises.count)
            }
            .frame(height: 420)

            PageDots(count: exercises.count, selection: index)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SWIPE PAGER")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Move between exercises.")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("Drag horizontally. Flick for momentum. Neighbors peek so you always know what's next.")
                .font(.system(size: 13))
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
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(seed.group.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(seed.accent)
            }

            Spacer()

            // Center: exercise name + accent line
            VStack(alignment: .leading, spacing: 14) {
                Rectangle()
                    .fill(seed.accent)
                    .frame(width: 44, height: 2)

                Text(seed.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // Bottom: scheme
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(seed.scheme)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
