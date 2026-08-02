#if DEBUG
//
//  MailComposeViewGallery.swift
//  vivobody
//
//  Presents the support composer and shows the environment footer
//  that gets prefilled into the body, so the wording can be read
//  without sending anything.
//
//  Simulators usually have no mail account, so `canSend` is false
//  there and the gallery exercises the `mailto:` fallback instead —
//  which is the branch worth eyeballing anyway, since it is the one
//  that leaves the app.
//

import SwiftUI
import VivoKit

struct MailComposeViewGallery: View {
    @State private var isComposing = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Text("MAIL COMPOSE")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)

            Text(MailComposeView.canSend
                 ? "canSend = true — tapping opens the in-app composer."
                 : "canSend = false — tapping falls back to mailto:.")
                .font(Typography.caption)
                .foregroundStyle(Tint.primary)

            Button {
                if MailComposeView.canSend {
                    isComposing = true
                } else if let url = SupportMail.mailtoURL {
                    openURL(url)
                }
            } label: {
                HStack {
                    Text("Contact & Support")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Spacer()
                    Image(systemName: "envelope")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(Ink.tertiary)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                .background(Surface.cardTint, in: RoundedRectangle(cornerRadius: Radius.chip))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("PREFILLED BODY")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                Text(SupportMail.body.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
            }

            Spacer()
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isComposing) {
            MailComposeView(
                recipient: SupportMail.recipient,
                subject: SupportMail.subject,
                body: SupportMail.body
            )
            .ignoresSafeArea()
        }
    }
}

#Preview("Mail Compose") {
    MailComposeViewGallery()
        .preferredColorScheme(.dark)
}

#endif
