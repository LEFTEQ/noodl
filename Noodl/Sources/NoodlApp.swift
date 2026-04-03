import SwiftUI

@main
struct NoodlApp: App {
    @State private var store = TodoStore()
    @State private var hotkey = GlobalHotkey()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .frame(width: 480, height: 520)
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
            SettingsView(store: store, hotkey: hotkey)
        }
    }
}
