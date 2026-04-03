import SwiftUI
import AppKit

struct SnippetRow: View {
    let snippet: Snippet
    var store: TodoStore
    @State private var copied = false
    @State private var editingTitle: String = ""
    @FocusState private var isEditingFocused: Bool

    private var isEditing: Bool {
        store.editingSnippetId == snippet.id
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(copied ? .green : .secondary)
                .frame(width: 14)

            if isEditing {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Snippet name…", text: $editingTitle)
                        .font(.system(size: 12, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($isEditingFocused)
                        .onSubmit { commitRename() }
                    Text(snippet.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(snippet.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isEditing ? Color.accentColor.opacity(0.06) : Color.clear)
        .onTapGesture {
            guard !isEditing else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippet.content, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snippet.content, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                editingTitle = snippet.title
                store.editingSnippetId = snippet.id
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                store.removeSnippet(snippet)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                editingTitle = snippet.title
                isEditingFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if store.editingSnippetId == snippet.id {
                        commitRename()
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func commitRename() {
        let name = editingTitle.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            store.renameSnippet(snippet, to: name)
        } else {
            store.editingSnippetId = nil
        }
    }
}
