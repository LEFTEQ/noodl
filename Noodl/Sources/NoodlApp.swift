import SwiftUI

@main
struct NoodlApp: App {
    @State private var store = TodoStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .frame(width: 320, height: 480)
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
            SettingsView(store: store)
        }
    }
}
