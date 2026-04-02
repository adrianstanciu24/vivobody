import SwiftUI

struct WorkoutsHistorySectionHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .textCase(nil)
            .listRowInsets(EdgeInsets(
                top: 12,
                leading: VivoSpacing.screenH,
                bottom: 10,
                trailing: VivoSpacing.screenH
            ))
    }
}

#Preview {
    List {
        Section {
            Text("Row")
        } header: {
            WorkoutsHistorySectionHeader(label: "THIS WEEK")
        }
    }
    .listStyle(.plain)
}
