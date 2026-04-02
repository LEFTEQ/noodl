import SwiftUI

struct StreamView: View {
    var store: TodoStore
    @Binding var activeSection: NoodlSection
    @State private var todosCollapsed: Bool
    @State private var snippetsCollapsed: Bool
    @State private var commandsCollapsed: Bool

    init(store: TodoStore, activeSection: Binding<NoodlSection>) {
        self.store = store
        self._activeSection = activeSection
        self._todosCollapsed = State(initialValue: store.isSectionCollapsed("todos"))
        self._snippetsCollapsed = State(initialValue: store.isSectionCollapsed("snippets"))
        self._commandsCollapsed = State(initialValue: store.isSectionCollapsed("commands"))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // TODOS
                    SectionHeader(
                        section: .todos,
                        title: "Todos",
                        count: store.totalOpen,
                        isCollapsed: $todosCollapsed
                    )
                    .id(NoodlSection.todos)
                    .onChange(of: todosCollapsed) { _, val in store.setSectionCollapsed("todos", collapsed: val) }

                    if !todosCollapsed {
                        if store.projects.isEmpty {
                            Text("No projects")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(store.projects) { project in
                                ProjectSection(project: project, store: store)
                            }
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // SNIPPETS
                    SectionHeader(
                        section: .snippets,
                        title: "Snippets",
                        count: store.snippets.count,
                        isCollapsed: $snippetsCollapsed
                    )
                    .id(NoodlSection.snippets)
                    .onChange(of: snippetsCollapsed) { _, val in store.setSectionCollapsed("snippets", collapsed: val) }

                    if !snippetsCollapsed {
                        if store.snippets.isEmpty {
                            Text("No snippets")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(store.snippets) { snippet in
                                SnippetRow(snippet: snippet, store: store)
                            }
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // COMMANDS
                    SectionHeader(
                        section: .commands,
                        title: "Commands",
                        count: store.commands.count,
                        isCollapsed: $commandsCollapsed
                    )
                    .id(NoodlSection.commands)
                    .onChange(of: commandsCollapsed) { _, val in store.setSectionCollapsed("commands", collapsed: val) }

                    if !commandsCollapsed {
                        if store.commands.isEmpty {
                            Text("No commands")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        } else {
                            ForEach(store.commands) { command in
                                CommandRow(command: command)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: activeSection) { _, section in
                withAnimation {
                    proxy.scrollTo(section, anchor: .top)
                }
                switch section {
                case .todos: if todosCollapsed { todosCollapsed = false }
                case .snippets: if snippetsCollapsed { snippetsCollapsed = false }
                case .commands: if commandsCollapsed { commandsCollapsed = false }
                }
            }
        }
    }
}
