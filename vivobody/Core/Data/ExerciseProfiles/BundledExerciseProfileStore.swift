import Foundation

struct BundledExerciseProfileStore {
    enum StoreError: Error {
        case missingResourcesRoot
        case missingProfile(String)
    }

    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let resourcesRoot: URL

    init(
        resourcesRoot: URL,
        decoder: JSONDecoder = JSONDecoder(),
        fileManager: FileManager = .default
    ) {
        self.resourcesRoot = resourcesRoot
        self.decoder = decoder
        self.fileManager = fileManager
    }

    init(
        bundle: Bundle = .main,
        decoder: JSONDecoder = JSONDecoder(),
        fileManager: FileManager = .default
    ) throws {
        self.decoder = decoder
        self.fileManager = fileManager
        resourcesRoot = try Self.resolveResourcesRoot(in: bundle, fileManager: fileManager)
    }

    func loadIndex() throws -> ExerciseProfileIndex {
        try decode(ExerciseProfileIndex.self, fromRelativePath: "profiles_v2/exercises.index.json")
    }

    func loadProfile(apiPath: String) throws -> ExerciseProfile {
        try decode(ExerciseProfile.self, fromRelativePath: apiPath)
    }

    func loadProfile(catalogID: String) throws -> ExerciseProfile {
        let index = try loadIndex()
        guard let entry = index.exercises.first(where: { $0.id == catalogID }) else {
            throw StoreError.missingProfile(catalogID)
        }
        return try loadProfile(apiPath: entry.apiPath)
    }

    func loadCatalog() throws -> [ExerciseCatalogItem] {
        let index = try loadIndex()

        return try index.exercises.map { entry in
            let profile = try loadProfile(apiPath: entry.apiPath)
            return makeCatalogItem(entry: entry, profile: profile)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, fromRelativePath relativePath: String) throws -> T {
        let url = resourcesRoot.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func makeCatalogItem(
        entry: ExerciseProfileIndexEntry,
        profile: ExerciseProfile
    ) -> ExerciseCatalogItem {
        let primaryTarget = profile.targets.primary.first ?? profile.targets.all.first
        let primaryTag = (primaryTarget?.label ?? defaultPrimaryTag(for: entry.motionFamily)).uppercased()
        let secondaryTags = [
            motionFamilyTag(for: entry.motionFamily),
            entry.isBilateral ? "BILATERAL" : "UNILATERAL"
        ].joined(separator: " · ")

        return ExerciseCatalogItem(
            id: entry.id,
            displayName: entry.displayName,
            description: entry.description,
            motionFamily: entry.motionFamily,
            isBilateral: entry.isBilateral,
            apiPath: entry.apiPath,
            muscleGroup: muscleGroup(for: primaryTarget?.id ?? primaryTarget?.label ?? entry.motionFamily),
            category: category(for: profile.exercise),
            primaryTag: primaryTag,
            secondaryTags: secondaryTags
        )
    }

    private func defaultPrimaryTag(for motionFamily: String) -> String {
        let lowercased = motionFamily.lowercased()

        if lowercased.contains("squat") {
            return "QUADS"
        }
        if lowercased.contains("hinge") {
            return "GLUTES"
        }

        return "OTHER"
    }

    private func motionFamilyTag(for motionFamily: String) -> String {
        motionFamily
            .replacing("_", with: " ")
            .uppercased()
    }

    private func muscleGroup(for source: String) -> MuscleGroup {
        let lowercased = source.lowercased()

        switch lowercased {
        case let value where value.contains("quad"),
             let value where value.contains("glute"),
             let value where value.contains("hamstring"),
             let value where value.contains("adductor"),
             let value where value.contains("calf"),
             let value where value.contains("leg"),
             let value where value.contains("squat"),
             let value where value.contains("hinge"):
            return .legs
        case let value where value.contains("back"),
             let value where value.contains("lat"),
             let value where value.contains("trap"):
            return .back
        case let value where value.contains("chest"),
             let value where value.contains("pec"):
            return .chest
        case let value where value.contains("shoulder"),
             let value where value.contains("delt"):
            return .shoulders
        case let value where value.contains("bicep"):
            return .biceps
        case let value where value.contains("tricep"):
            return .triceps
        case let value where value.contains("core"),
             let value where value.contains("ab"):
            return .core
        default:
            return .other
        }
    }

    private func category(for exercise: ExerciseProfileExercise) -> ExerciseCategory {
        let name = exercise.displayName.lowercased()

        if name.contains("dumbbell") {
            return .dumbbell
        }
        if name.contains("cable") {
            return .cable
        }
        if name.contains("machine") {
            return .machine
        }
        if name.contains("bodyweight") {
            return .bodyweight
        }
        if name.contains("squat") || name.contains("deadlift") || name.contains("good morning") {
            return .barbell
        }

        return .other
    }

    private static func resolveResourcesRoot(
        in bundle: Bundle,
        fileManager: FileManager
    ) throws -> URL {
        guard let resourceURL = bundle.resourceURL else {
            throw StoreError.missingResourcesRoot
        }

        let candidates = [
            resourceURL.appendingPathComponent("Resources/Generated/ExerciseProfiles"),
            resourceURL.appendingPathComponent("Generated/ExerciseProfiles"),
            resourceURL.appendingPathComponent("ExerciseProfiles")
        ]

        for candidate in candidates {
            let indexURL = candidate.appendingPathComponent("profiles_v2/exercises.index.json")
            if fileManager.fileExists(atPath: indexURL.path()) {
                return candidate
            }
        }

        if let enumerator = fileManager.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil
        ) {
            for case let fileURL as URL in enumerator {
                guard fileURL.lastPathComponent == "exercises.index.json",
                      fileURL.path().contains("profiles_v2")
                else {
                    continue
                }

                return fileURL
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
            }
        }

        throw StoreError.missingResourcesRoot
    }
}
