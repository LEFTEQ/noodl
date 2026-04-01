# Noodl 🍜

> Noodle on your tasks.

A lightweight macOS menu bar app for managing todos. Works with Claude Code's `/me:todolist` command — todos added from the CLI appear instantly in the menu bar.

## Features
- Menu bar popover with todos grouped by project
- Live file watching — changes sync instantly
- Priority support (!high, !low)
- Open todo count badge
- Launch at login

## Setup
```bash
tuist generate
open Noodl.xcodeproj
# Build & Run (Cmd+R)
```

## How it works
Noodl watches markdown files in `~/Documents/Work/personal/noodl/`. Each file is a project. The Claude Code `/me:todolist` command writes to these same files, creating a seamless CLI ↔ GUI workflow.

## File format
Each `.md` file in the noodl directory is a project:

```markdown
# ProjectName

- [ ] Open task
- [ ] Urgent task !high
- [x] Completed task

**Open: 2 | Done: 1**
```
