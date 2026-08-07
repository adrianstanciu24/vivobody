//  SafariView.swift
//  vivobody
//
//  In-app browser for the handful of public web pages the app links
//  to — currently the privacy policy reached from Settings > About.
//  Wraps `SFSafariViewController` so tapping the row presents a modal
//  sheet over the app instead of
//  ejecting the user into Safari.
//
//  That matters more here than in most apps: every other surface in
//  vivobody works offline and on-device, so a hard context switch out
//  to a browser is the single most jarring transition we ship. The
//  sheet keeps the app on screen behind it, and the Done button puts
//  the user back exactly where they were.
//
//  This is the only file that imports SafariServices — the same
//  one-boundary-per-system-framework rule HealthKit follows. Route
//  any new web link through `WebPage` + `SafariView` rather than
//  reaching for `Link` or `openURL`.
//

import SafariServices
import SwiftUI

// MARK: - Page identity

/// A web page to hand to the in-app browser.
///
/// `.sheet(item:)` needs an `Identifiable` payload, and conforming
/// `URL` itself would mean a retroactive conformance on a type we
/// don't own, so presentation goes through this wrapper instead.
struct WebPage: Identifiable {
    let url: URL

    var id: String { url.absoluteString }

    /// Fails for anything `SFSafariViewController` cannot open. The
    /// controller accepts only http and https and raises on other
    /// schemes, so `mailto:` and friends are rejected here and left
    /// for the caller to hand off to the system.
    init?(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        self.url = url
    }
}

// MARK: - Representable

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.delegate = context.coordinator
        controller.dismissButtonStyle = .done
        // Chrome is deliberately left untinted: iOS 26 deprecated
        // both bar and control tinting because it interferes with the
        // Liquid Glass background effects the system applies here.
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {
        // The coordinator is created once but `dismiss` is a fresh
        // value each update, so refresh the closure instead of
        // capturing a stale one at creation.
        context.coordinator.onFinish = { dismiss() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Bridges the Done button back into SwiftUI. Presented inside a
    /// SwiftUI sheet the controller is a child view controller, not a
    /// UIKit modal, so it cannot dismiss itself — without this the
    /// sheet's binding stays set and the sheet gets stuck open.
    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onFinish: () -> Void = {}

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onFinish()
        }
    }
}
