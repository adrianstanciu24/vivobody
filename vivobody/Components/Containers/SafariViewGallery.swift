#if DEBUG
//
    //  SafariViewGallery.swift
    //  vivobody
//
    //  Exercises the in-app browser against the two pages Settings links
    //  to, plus a `mailto:` URL that `WebPage` is expected to reject so
    //  the caller's system-handoff fallback can be felt too.
//
    //  Needs a network connection to render anything but chrome — the
    //  point of the gallery is the presentation and the Done button, not
    //  the page content.
//

    import SwiftUI
    import VivoKit

    struct SafariViewGallery: View {
        @State private var activePage: WebPage?
        @State private var rejected: String?

        private let privacy = PublicLinks.privacyPolicy
        private let support = PublicLinks.support
        private let mail = URL(string: "mailto:vivobodyapp@gmail.com")!

        var body: some View {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("SAFARI VIEW")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)

                open("Privacy Policy", privacy)
                open("Contact & Support", support)
                open("Mail link (rejected)", mail)

                if let rejected {
                    Text(rejected)
                        .font(Typography.caption)
                        .foregroundStyle(Tint.primary)
                }

                Spacer()
            }
            .padding(Space.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.ignoresSafeArea())
            .sheet(item: $activePage) { page in
                SafariView(url: page.url)
                    .ignoresSafeArea()
            }
        }

        private func open(_ title: String, _ url: URL) -> some View {
            Button {
                if let page = WebPage(url) {
                    rejected = nil
                    activePage = page
                } else {
                    rejected = "WebPage rejected \(url.scheme ?? "?"): — caller falls back to openURL"
                }
            } label: {
                HStack {
                    Text(title)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
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
        }
    }

    #Preview("Safari View") {
        SafariViewGallery()
            .preferredColorScheme(.dark)
    }

#endif
