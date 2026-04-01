import SwiftUI

struct AddTodoView: View {
    var store: TodoStore
    @Binding var isShowing: Bool

    @State private var title = ""
    @State private var selectedProjectIndex = 0
    @State private var priority: TodoItem.Priority? = nil
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField("Task title…", text: $title)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onSubmit { addTodo() }
                .padding(.horizontal, 12)
                .padding(.top, 8)

            HStack(spacing: 8) {
                // Project picker
                if !store.projects.isEmpty {
                    Picker("", selection: $selectedProjectIndex) {
                        ForEach(store.projects.indices, id: \.self) { index in
                            Text(store.projects[index].name).tag(index)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                // Priority picker
                Picker("", selection: $priority) {
                    Text("No priority").tag(Optional<TodoItem.Priority>.none)
                    Text("!high").tag(Optional<TodoItem.Priority>.some(.high))
                    Text("!low").tag(Optional<TodoItem.Priority>.some(.low))
                }
                .labelsHidden()
                .frame(width: 100)
            }
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Button("Add") {
                    addTodo()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || store.projects.isEmpty)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear {
            isTitleFocused = true
        }
    }

    private func addTodo() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !store.projects.isEmpty else { return }
        let project = store.projects[selectedProjectIndex]
        store.add(title: trimmed, priority: priority, to: project)
        dismiss()
    }

    private func dismiss() {
        title = ""
        priority = nil
        isShowing = false
    }
}
