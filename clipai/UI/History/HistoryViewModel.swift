import Foundation
import Combine
import AppKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var query: String = ""
    @Published var selectedID: String?
    @Published var statusMessage: String?

    private let store: SnippetStore
    private let pasteEngine: PasteEngine

    init(store: SnippetStore, pasteEngine: PasteEngine) {
        self.store = store
        self.pasteEngine = pasteEngine
    }

    func reload() {
        do {
            snippets = try store.list(query: query.isEmpty ? nil : query, limit: AppConstants.listLimit)
            if selectedID == nil || !snippets.contains(where: { $0.id == selectedID }) {
                selectedID = snippets.first?.id
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func pasteSelected() {
        guard let id = selectedID, let snippet = snippets.first(where: { $0.id == id }) else { return }
        do {
            let result = try pasteEngine.perform(snippet, mode: .paste)
            switch result {
            case .pasted:
                statusMessage = nil
            case .copiedOnly(let reason):
                switch reason {
                case .modeCopyOnly:
                    statusMessage = "Copied."
                case .accessibilityDenied:
                    statusMessage = "Copied. Enable Accessibility for clipai to auto-paste, then ⌘V."
                    AccessibilityPermission.openSystemSettings()
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func copySelected() {
        guard let id = selectedID, let snippet = snippets.first(where: { $0.id == id }) else { return }
        _ = try? pasteEngine.perform(snippet, mode: .copyOnly)
        statusMessage = "Copied."
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        try? store.delete(id: id)
        reload()
    }
}
