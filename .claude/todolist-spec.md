# Todolist Command Spec

Manage markdown-based project todos. One file per project.

## Usage

```
/me:todolist "fix the bug"              # Add todo to auto-detected project
/me:todolist Reservine "fix booking"    # Add to specific project
/me:todolist "urgent fix" !high         # Add with priority
/me:todolist list                       # List open todos for current project
/me:todolist list all                   # List all projects' todos
/me:todolist done "fix the bug"         # Mark as done
/me:todolist remove "fix the bug"       # Delete todo
/me:todolist                            # Add with auto-generated title from conversation context
```

## Arguments

- **Operation** (optional): `list`, `done`, `remove`, or default to `add`
- **Project override** (optional): capitalized word matching a known project (e.g. `FixIt`, `Reservine`)
- **Todo title** (optional): quoted string — if omitted on `add`, auto-generate from conversation context
- **Priority flag** (optional): `!high` or `!low`

## Execution Flow

### Step 1: Parse Arguments

Extract operation keyword (`list`, `done`, `remove`; default: `add`), optional project override (capitalized word not matching a keyword), todo title (quoted string), and priority flag (`!high` / `!low`).

Special cases:
- `list all` — operation is `list`, scope is all projects
- No arguments at all — operation is `add`, title will be auto-generated

### Step 2: Detect Project

Run `basename "$(pwd)"` to get the current directory name, then map:

| Directory basename | Project |
|--------------------|---------|
| `FixIt`, `FixIt-Web`, `fixit-services` | FixIt |
| `reservine`, `ReservineBack`, `ReservineWeb`, `Reservine-DX`, `reservine.web` | Reservine |
| `Turtor` | Turtor |
| `lovinka`, `lovinka-dashboard`, `lovinka-deployik`, `lovinka-infra` | Lovinka |
| `QTTa` | QTTa |
| `docsi` | Docsi |
| `Dixie` | Dixie |
| `PaperHome` | PaperHome |
| Anything under a `powerflow/`, `adf/`, or `deuss/` parent directory | Work |
| Unrecognized | Inbox |

If the user provided an explicit project override in the arguments, use that instead of the cwd mapping.

### Step 3: Confirm with User (Add only)

If operation is `add`:

1. If no title was provided, auto-generate a concise title (max ~8 words) from current conversation context.
2. Then confirm:

```
AskUserQuestion:
  header: "Todo"
  question: "Add this todo?"
  options:
    - label: "Confirm"
      description: "{project} | {title} {!priority if set}"
    - label: "Edit title"
      description: "Change the todo title"
    - label: "Edit project"
      description: "Change from detected project: {project}"
    - label: "Cancel"
      description: "Don't add this todo"
```

If "Edit title" — ask for new title, then re-confirm.
If "Edit project" — ask for new project name, then re-confirm.
If "Cancel" — stop execution.

### Step 4: Resolve File Path

```
NOODL_DIR = ~/Documents/Work/personal/noodl
PROJECT_FILE = {NOODL_DIR}/{ProjectName}.md
```

- Create `NOODL_DIR` directory if it doesn't exist.
- If the project file does not exist and operation is `add`, create it with the new-file template (see below).
- If the project file does not exist and operation is `list`, `done`, or `remove`, report "No todos found for {project}" and stop.

### Step 5: Execute Operation

#### Add

1. Read the existing file.
2. Insert `- [ ] {title} {!priority}` (omit priority suffix if not set) as a new line before the `**Open:` footer line.
3. Recalculate counts (Step 6), write file.

#### List

- **Single project** (`list`): Read `{ProjectName}.md`, display all `- [ ]` lines (open todos). If none, print "No open todos for {project}."
- **All projects** (`list all`): Read every `.md` file in `NOODL_DIR`, group output by project heading, show only open `- [ ]` lines. Skip files with no open todos.

#### Done

1. Read the file, find lines matching the given title (fuzzy: title is a substring of the line, case-insensitive).
2. If multiple matches found, disambiguate:
```
AskUserQuestion:
  header: "Multiple matches"
  question: "Which todo did you mean?"
  options:
    - label: "{full line text for each match}"
```
3. Toggle the matched `- [ ]` to `- [x]`.
4. Recalculate counts (Step 6), write file.

#### Remove

1. Read the file, fuzzy-match the title as above. Disambiguate if multiple matches.
2. Confirm deletion:
```
AskUserQuestion:
  header: "Remove todo"
  question: "Delete this todo?"
  options:
    - label: "Yes, delete"
      description: "{matched line}"
    - label: "Cancel"
```
3. If confirmed, delete the matched line.
4. Recalculate counts (Step 6), write file.

### Step 6: Recalculate Counts

After any write operation, count lines matching `- [ ]` (open) and `- [x]` (done) in the file.
Update the footer line: `**Open: {N} | Done: {M}**`

### Step 7: Display Confirmation

Show a concise summary of what was done:

```
# For add:
Added to FixIt:
  [ ] Fix geolocation drift on Android !high
  Open: 3 | Done: 1

# For done:
Marked done in FixIt:
  [x] Fix geolocation drift on Android
  Open: 2 | Done: 2

# For remove:
Removed from FixIt:
  Fix geolocation drift on Android
  Open: 2 | Done: 1

# For list:
FixIt — Open todos:
  [ ] Fix geolocation drift on Android !high
  [ ] Update README
  Open: 2 | Done: 1
```

## New File Template

```markdown
# {ProjectName}

- [ ] {title} {!priority}

**Open: 1 | Done: 0**
```

## File Format

```markdown
# {ProjectName}

- [ ] Some task title
- [ ] Urgent task !high
- [x] Completed task

**Open: 2 | Done: 1**
```

## Critical Paths

| Resource | Path |
|----------|------|
| **Noodl directory** | `~/Documents/Work/personal/noodl/` |
| **Project file pattern** | `{ProjectName}.md` (e.g., `FixIt.md`) |
| **Fallback file** | `Inbox.md` |
