import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var store: TodoStore
    @State private var directoryPath = ""
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Directory") {
                HStack {
                    TextField("Noodl directory", text: $directoryPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse…") {
                        browsForDirectory()
                    }
                }

                Text("Markdown files in this directory become projects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Noodl")
                    Spacer()
                    Text("Noodle on your tasks.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
        .onAppear {
            directoryPath = store.directoryURL.path(percentEncoded: false)
            launchAtLogin = (try? SMAppService.mainApp.status == .enabled) ?? false
        }
        .onChange(of: directoryPath) { _, newPath in
            let url = URL(filePath: newPath)
            store.updateDirectory(url)
        }
    }

    private func browsForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path(percentEncoded: false)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — launch at login requires proper app signing/notarization
        }
    }
}
