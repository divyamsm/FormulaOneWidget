import Foundation

@MainActor
final class F1SnapshotStore: ObservableObject {
    @Published private(set) var snapshot = F1WidgetSnapshot.placeholder
    @Published private(set) var isLoading = false

    private let service = OpenF1Service()

    func refresh() async {
        isLoading = true
        snapshot = await service.loadSnapshot()
        isLoading = false
    }
}
