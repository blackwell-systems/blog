---
title: "ZSH Line Editor (ZLE): Build Custom Keybindings and Understand How fzf Actually Works"
date: 2025-12-07
draft: false
tags: ["zsh", "zle", "fzf", "keybindings", "shell-scripting", "command-line", "productivity", "terminal", "widgets", "automation"]
categories: ["tutorials", "shell-scripting"]
description: "Learn ZSH Line Editor (ZLE) to create custom keybindings and widgets. Understand BUFFER, LBUFFER, RBUFFER, and how fzf's Ctrl+R and Ctrl+T actually work under the hood. Includes practical examples you can use immediately."
summary: "ZLE lets you create custom keybindings that manipulate your command line. Learn the fundamentals, build practical widgets (insert git branch, fuzzy file search), and understand how fzf integrates with ZSH."
---

You press Ctrl+R and get fuzzy history search. Press Ctrl+T and files appear in a searchable list. Press Ctrl+G and your current git branch inserts at the cursor.

The first two are fzf. The last one you can build yourself in 5 lines of ZSH.

Here's how ZLE (Zsh Line Editor) works and how to create custom keybindings that manipulate your command line.

## What is ZLE?

ZLE is ZSH's built-in line editor—the system that handles everything between pressing a key and executing a command. It manages:

- **The command buffer** (what you've typed)
- **Cursor position** (where you are in the line)
- **Keybindings** (what each keystroke does)
- **Editing operations** (insert, delete, move cursor, etc.)

Every keystroke triggers a **widget**—a function that manipulates the buffer. You can create your own widgets and bind them to any key.

## The Three Core Variables

ZLE exposes the command line as three variables:

```zsh
# If you've typed: "git commit -m "
# and cursor is here:      ^

$BUFFER   # "git commit -m " (entire line)
$LBUFFER  # "git commit -m " (left of cursor)
$RBUFFER  # "" (right of cursor)
$CURSOR   # 15 (cursor position, 0-indexed)
```

Modify these variables in a widget, and the command line updates instantly.

## Creating Your First Widget

Let's build a widget that inserts the current git branch:

```zsh
# Define the widget function
_insert_git_branch() {
    local branch=$(git branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        LBUFFER+="$branch"
    fi
}

# Register as a ZLE widget
zle -N _insert_git_branch

# Bind to Ctrl+G
bindkey '^G' _insert_git_branch
```

Now press Ctrl+G anywhere on the command line, and your branch name appears at the cursor.

**How it works:**
1. `git branch --show-current` gets the branch name
2. `LBUFFER+="$branch"` appends to the left buffer (inserts at cursor)
3. ZLE redraws the line automatically

## Practical Widgets You Can Use

### Insert Current Directory Basename

```zsh
_insert_dir_name() {
    LBUFFER+="${PWD:t}"  # :t = tail (basename)
}
zle -N _insert_dir_name
bindkey '^[d' _insert_dir_name  # Alt+D
```

Type `cd ` then press Alt+D to insert the current directory name.

### Insert Last Command's Last Argument

```zsh
_insert_last_arg() {
    local last_cmd=(${(z)history[$((HISTCMD-1))]})
    LBUFFER+="${last_cmd[-1]}"
}
zle -N _insert_last_arg
bindkey '^[.' _insert_last_arg  # Alt+.
```

This mimics Bash's Alt+. for "insert last argument from previous command."

### Clear Line to Kill Ring (Safe Clear)

```zsh
_clear_to_kill_ring() {
    CUTBUFFER=$BUFFER
    BUFFER=""
}
zle -N _clear_to_kill_ring
bindkey '^U' _clear_to_kill_ring  # Ctrl+U
```

Clears the line but saves it to kill ring (paste with Ctrl+Y).

### Quote Current Word

```zsh
_quote_word() {
    # Get words array
    local words=(${(z)LBUFFER})
    local last_word="${words[-1]}"

    if [[ -n "$last_word" ]]; then
        # Remove last word from LBUFFER
        LBUFFER="${LBUFFER%$last_word}"
        # Add it back quoted
        LBUFFER+="\"${last_word}\""
    fi
}
zle -N _quote_word
bindkey '^[q' _quote_word  # Alt+Q
```

Type a word, press Alt+Q, and it gets wrapped in quotes.

## Understanding BUFFER Manipulation

### Inserting Text

```zsh
# At cursor
LBUFFER+="text"

# At end of line
BUFFER+=" text"

# At beginning
BUFFER="text $BUFFER"

# Replace entire line
BUFFER="new command"
```

### Moving the Cursor

```zsh
# Move cursor (usually not needed, LBUFFER handles it)
CURSOR=0              # Move to beginning
CURSOR=${#BUFFER}     # Move to end
(( CURSOR += 5 ))     # Move right 5 chars
```

### Getting Word Under Cursor

```zsh
# Split buffer into words
local words=(${(z)LBUFFER})
local current_word="${words[-1]}"  # Last word in LBUFFER
```

## How fzf Integration Actually Works

When you press Ctrl+R with fzf, here's what happens:

```zsh
# Simplified version of fzf's history widget
fzf-history-widget() {
    # Run fzf with history as input
    local selected=$(fc -rl 1 |
        fzf --height 40% --reverse --query "$LBUFFER")

    if [[ -n "$selected" ]]; then
        # Extract command from "number  command" format
        local cmd=$(echo "$selected" | sed 's/^ *[0-9]* *//')
        # Replace buffer with selected command
        BUFFER="$cmd"
        # Move cursor to end
        CURSOR=${#BUFFER}
    fi

    # Redraw the line
    zle reset-prompt
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget
```

**Key parts:**
1. `fc -rl 1` - Get history (reverse chronological)
2. `fzf` - Pipe to interactive fuzzy finder
3. `BUFFER="$cmd"` - Replace command line with selection
4. `zle reset-prompt` - Force redraw

### fzf File Widget (Ctrl+T)

```zsh
fzf-file-widget() {
    # Find files with fd or find
    local selected=$(fd --type f --hidden --exclude .git |
        fzf --height 40% --reverse --multi)

    if [[ -n "$selected" ]]; then
        # Insert file paths at cursor
        LBUFFER+="${selected}"
    fi

    zle reset-prompt
}
zle -N fzf-file-widget
bindkey '^T' fzf-file-widget
```

**The magic:** fzf runs in a subprocess, returns the result, and ZLE updates the buffer. No plugin complexity—just pipes and variable manipulation.

## Building a Simple Fuzzy Finder (No fzf)

You can build basic fuzzy selection with pure ZLE:

```zsh
_simple_fuzzy_files() {
    # Get files in current directory
    local files=(*.*(N))  # Glob with null-glob

    if [[ ${#files} -eq 0 ]]; then
        return
    fi

    # Poor man's fuzzy: use select
    echo
    local PS3="Select file: "
    select file in "${files[@]}"; do
        if [[ -n "$file" ]]; then
            LBUFFER+="$file"
            break
        fi
    done

    zle reset-prompt
}
zle -N _simple_fuzzy_files
bindkey '^F' _simple_fuzzy_files  # Ctrl+F
```

This isn't fuzzy search (use real fzf for that), but shows how widgets can spawn interactive selection and insert results.

## Advanced: Multi-Line Editing

ZLE can handle multi-line commands:

```zsh
_insert_multiline_template() {
    local template='for item in "${items[@]}"; do
    echo "$item"
done'

    # Insert multi-line text
    LBUFFER+="$template"
}
zle -N _insert_multiline_template
bindkey '^[t' _insert_multiline_template  # Alt+T
```

Pressing Alt+T inserts a complete for-loop template.

## Working with the Kill Ring

ZLE has a kill ring (clipboard history):

```zsh
_show_kill_ring() {
    echo
    echo "Kill ring:"
    echo "$CUTBUFFER"
    zle reset-prompt
}
zle -N _show_kill_ring
bindkey '^[k' _show_kill_ring  # Alt+K
```

- `CUTBUFFER` - Currently killed text
- `killring` - Array of previous kills (less commonly used)

## Calling Other Widgets

You can chain widgets:

```zsh
_smart_accept() {
    # Trim trailing whitespace before accepting
    BUFFER="${BUFFER%"${BUFFER##*[![:space:]]}"}"

    # Call the normal accept-line widget
    zle accept-line
}
zle -N _smart_accept
bindkey '^M' _smart_accept  # Enter key
```

This wraps the default "accept line" behavior with preprocessing.

## Redrawing and Prompts

After modifying the buffer, you may need:

```zsh
zle reset-prompt    # Redraw prompt (needed after echo/print)
zle redisplay       # Redraw just the command line
zle clear-screen    # Clear screen and redraw
```

Use `reset-prompt` after any widget that outputs text (echo, print).

## Real-World Example: Smart Path Completion

Insert relative path to a file by fuzzy matching:

```zsh
_fuzzy_path_insert() {
    # Get all files recursively (limit depth for performance)
    local files=($(find . -maxdepth 3 -type f 2>/dev/null | sed 's|^\./||'))

    if [[ ${#files} -eq 0 ]]; then
        return
    fi

    # Use fzf if available
    if command -v fzf >/dev/null; then
        local selected=$(printf '%s\n' "${files[@]}" |
            fzf --height 40% --reverse --query="${LBUFFER##* }")

        if [[ -n "$selected" ]]; then
            # Replace last word with selected path
            local words=(${(z)LBUFFER})
            if [[ ${#words} -gt 0 ]]; then
                LBUFFER="${LBUFFER% *} $selected"
            else
                LBUFFER="$selected"
            fi
        fi
    fi

    zle reset-prompt
}
zle -N _fuzzy_path_insert
bindkey '^P' _fuzzy_path_insert  # Ctrl+P
```

Type `cat ` then Ctrl+P to fuzzy-find and insert a file path.

## Debugging Widgets

### Test a Widget Without Binding

```zsh
# Call widget directly from command line
zle _insert_git_branch
```

### Show Widget Info

```zsh
# List all widgets
zle -l

# Show what a key is bound to
bindkey '^G'
```

### Trace Widget Execution

```zsh
setopt XTRACE
# Press your keybinding
unsetopt XTRACE
```

## Common Pitfalls

### 1. Forgetting to Redraw

```zsh
_bad_widget() {
    echo "Debug info"  # Breaks display!
    LBUFFER+="text"
}
```

Fix: Always `zle reset-prompt` after echo/print.

### 2. Not Handling Empty Input

```zsh
_unsafe_widget() {
    local branch=$(git branch --show-current)
    LBUFFER+="$branch"  # What if not in git repo?
}
```

Fix: Check for empty strings or errors.

### 3. Breaking Multi-Line Commands

```zsh
_naive_widget() {
    BUFFER="new command"  # Destroys multi-line input!
}
```

Fix: Be careful replacing `$BUFFER` when user has multi-line input.

## Performance Considerations

Widgets should be fast (<100ms):

```zsh
# BAD: Network call in widget
_slow_widget() {
    LBUFFER+="$(curl -s api.example.com)"  # Blocks typing!
}

# GOOD: Use cached data
_fast_widget() {
    local cached="/tmp/api-cache"
    if [[ -f "$cached" ]]; then
        LBUFFER+="$(cat "$cached")"
    fi
}
```

Slow widgets make your shell feel broken. Cache data or use background jobs.

## Beyond fzf: What Else You Can Build

### 1. Snippet Expansion

```zsh
_expand_snippet() {
    local snippets=(
        'gco:git checkout'
        'gcm:git commit -m ""'
        'gp:git push origin'
    )

    # Get last word
    local words=(${(z)LBUFFER})
    local last="${words[-1]}"

    # Check for snippet match
    for snippet in "${snippets[@]}"; do
        local key="${snippet%%:*}"
        local expansion="${snippet#*:}"

        if [[ "$last" == "$key" ]]; then
            # Replace last word with expansion
            LBUFFER="${LBUFFER%$last}$expansion"
            break
        fi
    done
}
zle -N _expand_snippet
bindkey '^[e' _expand_snippet  # Alt+E
```

Type `gcm` then Alt+E → expands to `git commit -m ""`.

### 2. Smart Parenthesis Matching

```zsh
_insert_matching_paren() {
    LBUFFER+="()"
    ((CURSOR--))  # Move cursor between parens
}
zle -N _insert_matching_paren
bindkey '(' _insert_matching_paren
```

Type `(` and it inserts `()` with cursor in the middle.

### 3. Capitalize Current Word

```zsh
_capitalize_word() {
    local words=(${(z)LBUFFER})
    if [[ ${#words} -gt 0 ]]; then
        local last="${words[-1]}"
        local capitalized="${(C)last}"  # ZSH capitalizes
        LBUFFER="${LBUFFER%$last}$capitalized"
    fi
}
zle -N _capitalize_word
bindkey '^[c' _capitalize_word  # Alt+C
```

### 4. Toggle Sudo Prefix

```zsh
_toggle_sudo() {
    if [[ "$BUFFER" == sudo\ * ]]; then
        # Remove sudo
        BUFFER="${BUFFER#sudo }"
    else
        # Add sudo
        BUFFER="sudo $BUFFER"
    fi
}
zle -N _toggle_sudo
bindkey '^[s' _toggle_sudo  # Alt+S
```

Press Alt+S to add/remove `sudo` from the current command.

## How fzf Key Bindings Work

fzf's `key-bindings.zsh` file creates widgets that:

1. **Spawn fzf in a subprocess** with input (history, files, directories)
2. **Capture the selection** from fzf's stdout
3. **Modify BUFFER** with the result
4. **Redraw the prompt** with `zle reset-prompt`

Here's a simplified version of fzf's Ctrl+T (file finder):

```zsh
fzf-file-widget() {
    # Generate file list
    local files=$(find . -type f 2>/dev/null)

    # Pipe to fzf (interactive selection)
    local selected=$(echo "$files" |
        fzf --height 40% \
            --reverse \
            --multi \
            --preview 'head -50 {}')

    # Insert selection at cursor
    if [[ -n "$selected" ]]; then
        # Quote paths with spaces
        selected=$(echo "$selected" | sed "s/ /\\\\ /g")
        LBUFFER+="$selected"
    fi

    zle reset-prompt
}
zle -N fzf-file-widget
bindkey '^T' fzf-file-widget
```

**Key insight:** fzf isn't magic. It's just a TUI that reads stdin and writes stdout. The ZLE widget handles the integration.

## Understanding ZLE Modes

ZLE has different keymaps (like Vim modes):

- **emacs** (default) - Emacs-style bindings
- **viins** - Vi insert mode
- **vicmd** - Vi command mode

Set your mode:

```zsh
# Emacs mode (default)
bindkey -e

# Vi mode
bindkey -v
```

Check current keymap:

```zsh
echo $KEYMAP  # emacs, viins, or vicmd
```

Bind keys for specific modes:

```zsh
# Only in Vi insert mode
bindkey -M viins '^G' _insert_git_branch

# Only in Vi command mode
bindkey -M vicmd 'gb' _insert_git_branch
```

## Common Keybinding Syntax

ZSH keybinding syntax can be confusing:

```zsh
'^G'    # Ctrl+G
'^[g'   # Alt+G (escape sequence)
'^[[A'  # Up arrow
'^?'    # Backspace
'^H'    # Ctrl+H (often also backspace)
'^I'    # Tab
'^M'    # Enter
```

Find what a key sends:

```zsh
# Press keys after running this, then Ctrl+D
cat -v
```

Or use:

```zsh
# Shows key codes
showkey -a
```

## Advanced: Widgets with Arguments

Widgets can accept numeric arguments (Alt+5 before a command):

```zsh
_repeat_char() {
    local count=${NUMERIC:-1}  # Get numeric argument
    local char="x"
    LBUFFER+="${(l:$count::$char:)}"  # Repeat $count times
}
zle -N _repeat_char
bindkey '^X' _repeat_char  # Ctrl+X
```

Press Alt+10 then Ctrl+X to insert "xxxxxxxxxx".

## Real-World Integration: Directory Jumping

Build a simple directory jumper:

```zsh
_jump_to_project() {
    local projects=(~/workspace/*(N/))  # All dirs in workspace

    if [[ ${#projects} -eq 0 ]]; then
        return
    fi

    echo
    local PS3="Jump to: "
    select proj in "${projects[@]:t}"; do  # :t = basename only
        if [[ -n "$proj" ]]; then
            BUFFER="cd ~/workspace/$proj"
            zle accept-line  # Execute immediately
            break
        fi
    done

    zle reset-prompt
}
zle -N _jump_to_project
bindkey '^J' _jump_to_project  # Ctrl+J
```

Press Ctrl+J, select a project, and you're there.

## Widgets That Execute Commands

You can make widgets execute commands instead of just inserting text:

```zsh
_git_status_popup() {
    echo
    git status --short
    echo
    zle reset-prompt
}
zle -N _git_status_popup
bindkey '^[g' _git_status_popup  # Alt+G
```

Shows git status without executing a command. Press Alt+G from anywhere.

## Combining with ZSH Hooks

Widgets and hooks complement each other:

```zsh
# Hook: runs on directory change
_update_project_var() {
    PROJECT_NAME="${PWD:t}"
}
add-zsh-hook chpwd _update_project_var

# Widget: inserts the variable
_insert_project_name() {
    LBUFFER+="$PROJECT_NAME"
}
zle -N _insert_project_name
bindkey '^[p' _insert_project_name  # Alt+P
```

Hooks maintain state, widgets use that state to manipulate the command line.

## Debugging and Development

### Test Widget Without Keybinding

```zsh
# Define widget
_test_widget() {
    LBUFFER+="test"
}
zle -N _test_widget

# Call directly
zle _test_widget  # Inserts "test" at cursor
```

### Show All Bound Keys

```zsh
bindkey | grep insert_git_branch
```

### Temporarily Unbind

```zsh
# Save binding
local saved=$(bindkey '^G')

# Unbind
bindkey -r '^G'

# Restore later
eval "$saved"
```

## When to Use Widgets vs Aliases

**Use aliases for:**
- Simple command substitutions (`alias ll='ls -la'`)
- Fixed command patterns

**Use widgets for:**
- Context-aware insertion (current dir, git branch)
- Interactive selection (fuzzy finders)
- Buffer manipulation (quoting, expanding)
- Cursor-position-dependent behavior

Aliases run as commands. Widgets manipulate the command line before execution.

## Summary

ZLE widgets let you create custom keybindings that manipulate your command line:

- **Core variables:** `BUFFER`, `LBUFFER`, `RBUFFER`, `CURSOR`
- **Create widgets:** `zle -N widget_name`
- **Bind keys:** `bindkey '^G' widget_name`
- **Redraw:** `zle reset-prompt` after output

fzf works by creating widgets that spawn interactive TUIs and capture their output. You can build similar functionality with pure ZLE or integrate any CLI tool that reads stdin and writes stdout.

Start with simple widgets (insert git branch, insert directory name) and build up to complex interactive selection.

For more ZSH automation patterns, see my guide on [ZSH hooks](/posts/zsh-hooks-guide/).

---

**Further Reading:**
- [ZSH Manual: Zsh Line Editor](http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html)
- [fzf key-bindings.zsh](https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh) - See how fzf integration actually works
- [ZSH Hooks Guide](/posts/zsh-hooks-guide/) - Complement widgets with hooks

**Shell:** ZSH 5.0+
