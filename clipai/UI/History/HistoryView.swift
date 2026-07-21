import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryViewModel
    var onClose: () -> Void
    var onPasteAndClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .onChange(of: model.query) { _ in model.reload() }

            List(selection: $model.selectedID) {
                ForEach(model.snippets) { snippet in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.previewText.isEmpty ? snippet.kind.rawValue : snippet.previewText)
                                .lineLimit(2)
                            HStack {
                                if let name = snippet.sourceAppName {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(snippet.updatedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(snippet.kind == .image ? "🖼" : "Aa")
                    }
                    .tag(snippet.id as String?)
                }
            }
            .frame(minHeight: 240)

            if let status = model.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            HStack {
                Button("Paste") { onPasteAndClose() }
                    .keyboardShortcut(.defaultAction)
                Button("Copy") { model.copySelected() }
                Button("Delete") { model.deleteSelected() }
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(8)
        }
        .frame(width: 420, height: 360)
        .onAppear { model.reload() }
    }
}
