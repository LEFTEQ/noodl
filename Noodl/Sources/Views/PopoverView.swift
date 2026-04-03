import SwiftUI
import AppKit

struct PopoverView: View {
    var store: TodoStore
    @State private var showAddForm = false
    @State private var activeSection: NoodlSection = .todos
    @State private var keyMonitor: Any?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 0) {
            // Left column: Memory sidebar
            MemorySidebar()
                .frame(width: 180)

            Divider()

            // Right column: Tools
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Noodl")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showAddForm.toggle()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("Add item")

                    Button {
                        openSettings()
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // Pill bar
                PillBar(
                    todoCount: store.totalOpen,
                    snippetCount: store.snippets.count,
                    commandCount: store.commands.count,
                    activeSection: activeSection
                ) { section in
                    activeSection = section
                }

                Divider()

                // Unified add form
                if showAddForm {
                    UnifiedAddView(store: store, isShowing: $showAddForm)
                    Divider()
                }

                // Stream
                StreamView(store: store, activeSection: $activeSection)
            }
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "v",
                   !showAddForm {
                    if store.pasteAsSnippet() != nil {
                        activeSection = .snippets
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            keyMonitor = nil
        }
    }
}
