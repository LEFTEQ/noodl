import SwiftUI

enum AddItemType: String, CaseIterable {
    case todo = "Todo"
    case snippet = "Snippet"
    case command = "Command"
}

struct UnifiedAddView: View {
    var store: TodoStore
    @Binding var isShowing: Bool

    @State private var itemType: AddItemType = .todo
    @State private var title = ""
    @State private var content = ""
    @State private var selectedProjectIndex = 0
    @State private var priority: TodoItem.Priority? = nil
    @State private var commandKind: QuickCommand.Kind = .shell
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $itemType) {
                ForEach(AddItemType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            TextField("Title…", text: $title)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onSubmit { addItem() }
                .padding(.horizontal, 12)

            if itemType == .snippet || itemType == .command {
                TextEditor(text: $content)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 60)
                    .scrollContentBackground(.hidden)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 12)
            }

            HStack(spacing: 8) {
                if itemType == .todo {
                    if !store.projects.isEmpty {
                        Picker("", selection: $selectedProjectIndex) {
                            ForEach(store.projects.indices, id: \.self) { index in
                                Text(store.projects[index].name).tag(index)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    Picker("", selection: $priority) {
                        Text("None").tag(Optional<TodoItem.Priority>.none)
                        Text("!high").tag(Optional<TodoItem.Priority>.some(.high))
                        Text("!low").tag(Optional<TodoItem.Priority>.some(.low))
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }

                if itemType == .command {
                    Picker("Kind", selection: $commandKind) {
                        Text("Shell").tag(QuickCommand.Kind.shell)
                        Text("AI").tag(QuickCommand.Kind.ai)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Button("Add") { addItem() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear { isTitleFocused = true }
    }

    private func addItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        switch itemType {
        case .todo:
            guard !store.projects.isEmpty else { return }
            let project = store.projects[selectedProjectIndex]
            store.add(title: trimmedTitle, priority: priority, to: project)
        case .snippet:
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            store.addSnippet(title: trimmedTitle, content: trimmedContent.isEmpty ? trimmedTitle : trimmedContent)
        case .command:
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else { return }
            store.addCommand(title: trimmedTitle, command: trimmedContent, kind: commandKind)
        }

        title = ""
        content = ""
        priority = nil
        isTitleFocused = true
    }

    private func dismiss() {
        title = ""
        content = ""
        priority = nil
        isShowing = false
    }
}
