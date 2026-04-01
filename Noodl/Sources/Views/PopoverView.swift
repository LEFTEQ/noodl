import SwiftUI

struct PopoverView: View {
    var store: TodoStore
    @State private var showAddTodo = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Noodl")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    showAddTodo.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Add todo")

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

            Divider()

            // Add todo inline form
            if showAddTodo {
                AddTodoView(store: store, isShowing: $showAddTodo)
                Divider()
            }

            // Project list
            if store.projects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No projects found")
                        .foregroundStyle(.secondary)
                    Text(store.directoryURL.path(percentEncoded: false))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(store.projects) { project in
                            ProjectSection(project: project, store: store)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Footer
            HStack {
                Text("Open: \(store.totalOpen)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("Done: \(store.totalDone)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reload") {
                    store.reload()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
