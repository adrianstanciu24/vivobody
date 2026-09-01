//
//  SoundResourcesTests.swift
//  vivobodyTests
//
//  Proves every runtime sound resolves to a non-empty, decodable bundled
//  file, including prefixed scrub variants and the rest notification.
//

import AVFoundation
import Foundation
import Testing
@testable import vivobody

@MainActor
struct SoundResourcesTests {
    @Test func everyRuntimeSoundIsBundledAndReadable() throws {
        for resource in Self.runtimeResources {
            let url = Bundle.main.url(
                forResource: resource.name,
                withExtension: resource.fileExtension
            )
            #expect(
                url != nil,
                "Missing bundled sound: \(resource.name).\(resource.fileExtension)"
            )
            guard let url else { continue }

            let audioFile = try AVAudioFile(forReading: url)
            #expect(
                audioFile.length > 0,
                "Empty bundled sound: \(resource.name).\(resource.fileExtension)"
            )
        }
    }

    private static var runtimeResources: [(name: String, fileExtension: String)] {
        let effects = Sounds.Effect.allCases.map { effect in
            (
                name: effect.resourceName,
                fileExtension: effect.isRecorded ? "wav" : "caf"
            )
        }
        let scrubDetents = ["reps", "load"].flatMap { role in
            (1 ... 6).map { variant in
                (
                    name: "sfx-scrub-\(role)-\(variant)",
                    fileExtension: "caf"
                )
            }
        }
        return effects + scrubDetents + [
            (name: "sfx-rest-done", fileExtension: "caf"),
        ]
    }
}
