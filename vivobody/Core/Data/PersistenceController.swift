import SwiftData
import SwiftUI

@Observable
final class PersistenceController {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func delete(_ object: any PersistentModel) {
        modelContext.delete(object)
        try? modelContext.save()
    }
}

private struct PersistenceInjector: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .environment(PersistenceController(modelContext: modelContext))
    }
}

extension View {
    func withPersistence() -> some View {
        modifier(PersistenceInjector())
    }
}
