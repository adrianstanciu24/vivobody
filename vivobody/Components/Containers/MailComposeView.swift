//  MailComposeView.swift
//  vivobody
//
//  The support email, composed without leaving the app. Wraps
//  `MFMailComposeViewController` so Settings > Contact & Support
//  opens a prefilled message sheet rather than a web page the user
//  then has to read an address off of.
//
//  Not every device can send mail — the Mail app can be deleted and
//  an account may never have been added — so callers check
//  `MailComposeView.canSend` first and fall back to handing
//  `SupportMail.mailtoURL` to the system.
//
//  This is the only file that imports MessageUI, matching the
//  one-boundary-per-system-framework rule HealthKit and
//  SafariServices already follow.
//

import MessageUI
import SwiftUI

// MARK: - Message contents

/// Recipient, subject, and the prefilled body for a support email.
enum SupportMail {
    static let recipient = "vivobodyapp@gmail.com"
    static let subject = "Vivobody Support"

    /// Leading blank lines park the cursor above a one-line
    /// environment footer. The footer is created on-device as plain
    /// text in a draft the user can edit or delete. No support message
    /// or diagnostic information is sent unless the user taps Send.
    static var body: String {
        "\n\n—\nVivobody \(appVersion) (\(buildNumber)) · iOS \(systemVersion) · \(deviceIdentifier)"
    }

    /// System-composer fallback for devices where `MFMailComposeViewController`
    /// is unavailable. `URLComponents` handles percent-encoding the
    /// subject and body.
    static var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private static var systemVersion: String {
        UIDevice.current.systemVersion
    }

    /// The hardware identifier ("iPhone17,1"), which `UIDevice.model`
    /// does not expose — it only ever reports "iPhone". Worth having
    /// in a bug report about layout or performance.
    private static var deviceIdentifier: String {
        var info = utsname()
        guard uname(&info) == 0 else { return "unknown" }
        // Copied out of `info` first: passing `&info.machine` to
        // withUnsafePointer while `info` is still mutable is an
        // overlapping-access error.
        let machine = info.machine
        return withUnsafePointer(to: machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: machine)) {
                String(validatingCString: $0) ?? "unknown"
            }
        }
    }
}

// MARK: - Representable

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String

    @Environment(\.dismiss) private var dismiss

    /// False when no mail account is set up, or the Mail app has been
    /// removed. Presenting the composer anyway shows an empty sheet
    /// the user cannot send from, so check this first.
    static var canSend: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_: MFMailComposeViewController, context: Context) {
        // Same reasoning as SafariView: the coordinator is built once
        // while `dismiss` is refreshed every update, so re-bind the
        // closure instead of capturing a stale one.
        context.coordinator.onFinish = { dismiss() }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Sending and cancelling both land here. Presented inside a
    /// SwiftUI sheet the composer cannot dismiss itself, so the
    /// binding has to be cleared from this side.
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var onFinish: () -> Void = {}

        func mailComposeController(
            _: MFMailComposeViewController,
            didFinishWith _: MFMailComposeResult,
            error _: Error?
        ) {
            onFinish()
        }
    }
}
