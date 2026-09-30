import SwiftUI
import SwiftData

/// Phase (a) placeholder: lists the seeded library so the data layer can be verified
/// on device. Replaced by the environment picker in phase (b).
struct RootView: View {
    @Query(sort: \SpeakEnvironment.sortOrder) private var environments: [SpeakEnvironment]

    var body: some View {
        NavigationStack {
            List(environments) { environment in
                Section {
                    ForEach(environment.sortedCategories) { category in
                        LabeledContent(category.name, value: "\(category.phrases.count) phrases")
                    }
                } header: {
                    Label(environment.name, systemImage: environment.symbolName)
                        .font(.headline)
                }
            }
            .navigationTitle("ALSpeak")
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.shared)
}
