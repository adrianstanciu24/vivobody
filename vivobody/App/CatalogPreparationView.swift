//
//  CatalogPreparationView.swift
//  vivobody
//
//  Honest launch state shown only when the bundled exercise catalog needs its
//  first install or version update before catalog-dependent UI can be used.
//

import SwiftUI
import VivoKit

struct CatalogPreparationView: View {
    let hasFailed: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Space.xl) {
            if hasFailed {
                Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Tint.primary)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(Tint.primary)
                    .accessibilityHidden(true)
            }

            VStack(spacing: Space.sm) {
                Text(hasFailed ? "Exercise library unavailable" : "Preparing exercise library")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(
                    hasFailed
                        ? "Your workout data is safe. Try preparing the exercise library again."
                        : "This should only take a moment."
                )
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
            }

            if hasFailed {
                Button("Try again", systemImage: "arrow.clockwise", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("catalogPreparationRetryButton")
            }
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("catalogPreparationStatus")
    }
}

#Preview("Preparing catalog") {
    CatalogPreparationView(hasFailed: false) {}
}

#Preview("Catalog error") {
    CatalogPreparationView(hasFailed: true) {}
}
