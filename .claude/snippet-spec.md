# Snippet Command Spec

Manage quick-copy text snippets in `_snippets.md`. Optionally AI-improve text via prompt-engineer agent.

## Usage

```
/me:snippet "SSH VPS" "ssh deploy@116.202.15.49"    # Add snippet with title and content
/me:snippet "Email intro"                             # Add snippet, prompt for content
/me:snippet "Meeting msg" "Let's sync" --skip         # Add without AI improvement
/me:snippet list                                      # List all snippets
/me:snippet remove "SSH VPS"                          # Remove a snippet
```

## Arguments

- **Operation** (optional): `list`, `remove`, or default to `add`
- **Title** (required for add/remove): first quoted string
- **Content** (optional for add): second quoted string — if omitted, ask user
- **--skip** flag (optional): skip the AI improvement step

## File

```
SNIPPETS_FILE = ~/Documents/Work/personal/noodl/_snippets.md
```

## File Format

```markdown
# Snippets

## Title Here
Content to copy goes here.
Can be multiline.

## Another Snippet
More content here.
```

Each `## heading` is a snippet title. Everything between headings is the copyable content.

## Execution Flow

### Step 1: Parse Arguments

Extract operation (`list`, `remove`; default: `add`), title (first quoted string), content (second quoted string), and `--skip` flag.

### Step 2: Execute Operation

#### Add

1. If no content was provided, ask via AskUserQuestion (free text input).
2. **AI Improvement** (unless `--skip` is passed):
   - Launch the `prompt-engineer` agent with subagent_type `prompt-engineer`
   - Provide the snippet content and ask the agent to improve it for clarity, conciseness, and effectiveness
   - The agent should return an improved version
   - Show user BOTH versions via AskUserQuestion:
     ```
     AskUserQuestion:
       header: "Improve?"
       question: "Use the AI-improved version?"
       options:
         - label: "Use improved"
           description: "{improved_content}"
         - label: "Keep original"
           description: "{original_content}"
         - label: "Edit manually"
           description: "Provide your own version"
     ```
3. Confirm the final snippet:
   ```
   AskUserQuestion:
     header: "Snippet"
     question: "Add this snippet?"
     options:
       - label: "Confirm"
         description: "{title}: {content preview...}"
       - label: "Edit"
         description: "Change title or content"
       - label: "Cancel"
   ```
4. Read `_snippets.md` (create if doesn't exist).
5. Append new section at end of file:
   ```
   ## {Title}
   {Content}
   ```
6. Write file.

#### List

Read `_snippets.md`, display all snippets:
```
Snippets:
  1. SSH VPS — ssh deploy@116.202.15.49
  2. Docker Restart — docker compose restart postgres
  3. Meeting Invite — Hi, I'd like to schedule...
```

Show title and first line of content (truncated to ~50 chars).

#### Remove

1. Fuzzy-match the given title against snippet titles (case-insensitive substring).
2. If multiple matches, disambiguate with AskUserQuestion.
3. Confirm deletion:
   ```
   AskUserQuestion:
     header: "Remove snippet"
     question: "Delete this snippet?"
     options:
       - label: "Yes, delete"
         description: "{title}: {content preview}"
       - label: "Cancel"
   ```
4. Remove the `## Title` line and all content lines until the next `##` heading or end of file.
5. Write file.

### Step 3: Display Confirmation

```
# For add:
Added snippet:
  SSH VPS — ssh deploy@116.202.15.49

# For remove:
Removed snippet:
  SSH VPS

# For list:
3 snippets in _snippets.md
```

## New File Template

When `_snippets.md` doesn't exist:

```markdown
# Snippets

## {Title}
{Content}
```

## Critical Paths

| Resource | Path |
|----------|------|
| **Snippets file** | `~/Documents/Work/personal/noodl/_snippets.md` |
| **Noodl directory** | `~/Documents/Work/personal/noodl/` |
