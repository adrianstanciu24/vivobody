//
//  EndWorkoutConfirmationDialog.swift
//  vivobody
//
//  Confirms whether to archive or discard an active workout. A focused
//  dialog gives each action its own adaptive text color while keeping
//  the workout visible behind the decision.
//

import SwiftUI
import VivoKit

struct EndWorkoutConfirmationDialog: View {
    let title: String
    let message: String
    let finishTitle: String?
    let onFinish: () -> Void
    let onDiscard: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        dialog
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .accessibilityAction(.escape, onCancel)
    }

    private var dialog: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.md) {
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)

                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Space.sm) {
                if let finishTitle {
                    actionButton(finishTitle, color: Tint.primaryText, action: onFinish)
                }
                actionButton("Discard", role: .destructive, color: Tint.danger, action: onDiscard)
                actionButton("Cancel", role: .cancel, color: Ink.primary, action: onCancel)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Surface.edgeBright, lineWidth: 1)
        }
        .padding(.horizontal, Space.gutter)
    }

    private func actionButton(
        _ title: String,
        role: ButtonRole? = nil,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: Space.rowMin)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Surface.cardTintBright, in: Capsule())
    }
}
