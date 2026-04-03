import SwiftUI

@main
struct NoodlApp: App {
    @State private var store = TodoStore()
    @State private var hotkey = GlobalHotkey()
    @State private var memoryStore = MemoryStore(
        baseURL: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Work/personal/noodl")
    )
    @State private var screenshotService = ScreenshotService()
    @State private var voiceRecorder = VoiceRecorder()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                store: store,
                memoryStore: memoryStore,
                screenshotService: screenshotService,
                voiceRecorder: voiceRecorder
            )
            .frame(width: 480, height: 520)
            .onAppear {
                memoryStore.startIfNeeded()
                screenshotService.configure(memoryStore: memoryStore)
                screenshotService.hotkey.onTrigger = { [screenshotService] in
                    screenshotService.takeScreenshot()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                if store.totalOpen > 0 {
                    Text("\(store.totalOpen)")
                        .font(.caption2)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store, hotkey: hotkey, screenshotHotkey: screenshotService.hotkey)
        }
    }
}
