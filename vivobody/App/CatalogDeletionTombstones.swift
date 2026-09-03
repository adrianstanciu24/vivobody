//
//  CatalogDeletionTombstones.swift
//  vivobody
//
//  UserDefaults-backed record of bundled catalog identities the user removed.
//  Launch reconciliation reads these tombstones; delete and reset mutations
//  update them only after their SwiftData transaction commits.
//

import Foundation

enum CatalogDeletionTombstones {
    static func ids(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: SettingsKey.hiddenBundledCatalogIDs) ?? [])
    }

    static func record(_ catalogID: String, in defaults: UserDefaults = .standard) {
        var hiddenIDs = ids(in: defaults)
        hiddenIDs.insert(catalogID)
        defaults.set(hiddenIDs.sorted(), forKey: SettingsKey.hiddenBundledCatalogIDs)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: SettingsKey.hiddenBundledCatalogIDs)
    }
}
