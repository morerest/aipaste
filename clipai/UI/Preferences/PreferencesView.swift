import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section("History") {
                Stepper(value: $model.maxSnippetCount, in: 50...5000, step: 50) {
                    Text("Max items: \(model.maxSnippetCount)")
                }
                .onChange(of: model.maxSnippetCount) { _ in model.applyCapacity() }
                Button("Clear All History…") { model.clearHistory() }
            }
            Section("Privacy") {
                Text("Ignored apps (bundle IDs)")
                List {
                    ForEach(model.ignored, id: \.self) { id in
                        HStack {
                            Text(id).font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("Remove") { model.removeIgnore(id) }
                        }
                    }
                }
                .frame(minHeight: 120)
                HStack {
                    TextField("com.example.app", text: $model.newIgnore)
                    Button("Add") { model.addIgnore() }
                }
            }
            Section("System") {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
                    .onChange(of: model.launchAtLogin) { _ in model.applyLaunch() }
                HStack {
                    Text(model.accessibilityLabel)
                    Spacer()
                    Button("Open Accessibility Settings") {
                        AccessibilityPermission.openSystemSettings()
                        model.refreshAccessibilityLabel()
                    }
                }
            }
            Section("About") {
                Text("clipai Phase 1 — local only, no cloud upload.")
                Text("Data: ~/Library/Application Support/clipai/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 480, height: 420)
        .onAppear { model.refreshAccessibilityLabel() }
    }
}
