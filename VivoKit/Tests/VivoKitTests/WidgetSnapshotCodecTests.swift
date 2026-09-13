//
//  WidgetSnapshotCodecTests.swift
//  VivoKitTests
//
//  Locks the App Group snapshot compatibility contract: every current payload
//  round-trips, legacy raw JSON remains readable, and rejected or absent data
//  resolves to a deliberate widget empty state instead of blank content.
//

import Foundation
import Testing
@testable import VivoKitSnapshotCore

struct WidgetSnapshotCodecTests {
    @Test func everyCurrentSnapshotRoundTrips() throws {
        try expectRoundTrip(UpNextSnapshot.placeholder)
        try expectRoundTrip(ConsistencySnapshot.placeholder)
        try expectRoundTrip(SignatureSnapshot.placeholder)
        try expectRoundTrip(TrainingLoadSnapshot.placeholder)
        try expectRoundTrip(ActiveWorkoutSnapshot.placeholder)
    }

    @Test func obsoleteEnvelopeUsesExplicitFallback() throws {
        let payload = UpNextSnapshot.placeholder
        let obsolete = VersionedSnapshot(
            version: WidgetSnapshotVersion.current - 1,
            payload: payload
        )
        let data = try JSONEncoder().encode(obsolete)

        #expect(WidgetSnapshotCodec.decode(UpNextSnapshot.self, from: data) == nil)
        #expect(
            WidgetSnapshotCodec.decode(
                UpNextSnapshot.self,
                from: data,
                fallback: .empty
            ) == .empty
        )
    }

    @Test func malformedPayloadUsesExplicitFallback() {
        let malformed = Data(#"{"version":5,"payload":not-json}"#.utf8)

        #expect(WidgetSnapshotCodec.decode(UpNextSnapshot.self, from: malformed) == nil)
        #expect(
            WidgetSnapshotCodec.decode(
                UpNextSnapshot.self,
                from: malformed,
                fallback: .empty
            ) == .empty
        )
    }

    @Test func missingPayloadUsesExplicitFallback() {
        #expect(WidgetSnapshotCodec.decode(UpNextSnapshot.self, from: nil) == nil)
        #expect(
            WidgetSnapshotCodec.decode(
                UpNextSnapshot.self,
                from: nil,
                fallback: .empty
            ) == .empty
        )
    }

    @Test func legacyUnversionedPayloadRemainsReadable() throws {
        let payload = UpNextSnapshot.placeholder
        let legacyData = try JSONEncoder().encode(payload)

        #expect(
            WidgetSnapshotCodec.decode(UpNextSnapshot.self, from: legacyData)
                == payload
        )
    }

    private func expectRoundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try #require(WidgetSnapshotCodec.encode(value))
        let decoded = try #require(WidgetSnapshotCodec.decode(T.self, from: data))
        #expect(decoded == value)
    }
}
