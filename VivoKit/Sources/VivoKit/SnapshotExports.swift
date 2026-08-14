//
//  SnapshotExports.swift
//  VivoKit
//
//  Re-exports the portable widget snapshot contract so app and extension
//  clients keep one `import VivoKit` while host-side tests compile the codec
//  without UIKit, AppIntents, ActivityKit, or a simulator.
//

@_exported import VivoKitSnapshotCore
