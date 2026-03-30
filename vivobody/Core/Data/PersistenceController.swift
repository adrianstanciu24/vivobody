import SwiftData
import SwiftUI

@Observable
final class PersistenceController {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
