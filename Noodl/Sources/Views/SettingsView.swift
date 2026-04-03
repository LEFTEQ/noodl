import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var store: TodoStore
    var hotkey: GlobalHotkey
    var screenshotHotkey: ScreenshotHotkey
    @State private var directoryPath = ""
    @State private var launchAtLogin = false
    @State private var isRecordingHotkey = false
    @State private var isRecordingScreenshotHotkey = false

    var body: some View {
        Form {
            Section("Directory") {
                HStack {
                    TextField("Noodl directory", text: $directoryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browseForDirectory() }
                }
                Text("Markdown files in this directory become projects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Hotkey") {
                HStack {
                    Text("Open Noodl")
                    Spacer()
                    if isRecordingHotkey {
                        Text("Press shortcut…")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Text(hotkey.shortcutDescription)
                            .foregroundStyle(.secondary)
                    }
                    Button(isRecordingHotkey ? "Cancel" : "Record") {
                        isRecordingHotkey.toggle()
                        isRecordingScreenshotHotkey = false
                    }
                    .controlSize(.small)
                    if hotkey.isEnabled {
                        Button("Clear") { hotkey.clearShortcut() }
                            .controlSize(.small)
                    }
                }
            }

            Section("Screenshot Hotkey") {
                HStack {
                    Text("Take Screenshot")
                    Spacer()
                    if isRecordingScreenshotHotkey {
                        Text("Press shortcut…")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Text(screenshotHotkey.shortcutDescription)
                            .foregroundStyle(.secondary)
                    }
                    Button(isRecordingScreenshotHotkey ? "Cancel" : "Record") {
                        isRecordingScreenshotHotkey.toggle()
                        isRecordingHotkey = false
                    }
                    .controlSize(.small)
                    if screenshotHotkey.isEnabled {
                        Button("Clear") { screenshotHotkey.clearShortcut() }
                            .controlSize(.small)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
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
            store.updateDirectory(URL(filePath: newPath))
        }
        .task(id: isRecordingHotkey) {
            guard isRecordingHotkey else { return }
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
                guard !mods.isEmpty else { return event }
                self.hotkey.setShortcut(flags: event.modifierFlags, code: event.keyCode)
                self.isRecordingHotkey = false
                return nil
            }
            while isRecordingHotkey {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        .task(id: isRecordingScreenshotHotkey) {
            guard isRecordingScreenshotHotkey else { return }
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
                guard !mods.isEmpty else { return event }
                self.screenshotHotkey.setShortcut(flags: event.modifierFlags, code: event.keyCode)
                self.isRecordingScreenshotHotkey = false
                return nil
            }
            while isRecordingScreenshotHotkey {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }

    private func browseForDirectory() {
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
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
    }
}
