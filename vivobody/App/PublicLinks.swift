//
//  PublicLinks.swift
//  vivobody
//
//  Canonical public web destinations owned by Vivobody. Every
//  in-app link uses this single source so a hosting or domain change
//  cannot leave Settings and debug galleries pointing at different
//  versions of the privacy and support pages.
//

import Foundation

enum PublicLinks {
    static let website = URL(string: "https://vivobody.app/")!
    static let privacyPolicy = URL(string: "https://vivobody.app/privacy/")!
    static let support = URL(string: "https://vivobody.app/support/")!
}
