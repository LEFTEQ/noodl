# Noodl

macOS menu bar todo manager. Reads/writes markdown todo files from `~/Documents/Work/personal/noodl/`.

## Stack
- Swift 6, SwiftUI, macOS 15+
- Tuist for project management
- MenuBarExtra with .window style (popover)
- @Observable for state management
- FSEvents/DispatchSource for file watching

## File Format
Each project has one `.md` file:
```markdown
# ProjectName

- [ ] Task title
- [ ] Task !high
- [x] Done task

**Open: N | Done: M**
```

## Build
```bash
tuist generate
xcodebuild -scheme Noodl -destination 'platform=macOS' build
```

## Project Structure
```
Noodl/Sources/
  NoodlApp.swift          — App entry point, MenuBarExtra setup
  Models/
    TodoItem.swift        — Todo model with priority
    TodoProject.swift     — Project model (one per .md file)
  Services/
    MarkdownParser.swift  — Parse/serialize markdown todo files
    FileWatcher.swift     — DispatchSource-based directory watcher
    TodoStore.swift       — @Observable state, file I/O orchestration
  Views/
    PopoverView.swift     — Main popover container
    ProjectSection.swift  — DisclosureGroup per project
    TodoRow.swift         — Single todo row with checkbox + priority badge
    AddTodoView.swift     — Inline add form
    SettingsView.swift    — Settings window
```

## Key Decisions
- `TodoStore` is `@MainActor` for Swift 6 concurrency safety
- `FileWatcher` is `@unchecked Sendable` (manual thread safety via serial queue)
- No sandbox entitlements — this is a dev tool, direct file access
- LSUIElement = true → no Dock icon
