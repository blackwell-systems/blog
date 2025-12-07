---
title: "From Shell Scripts to Go: Building a Multi-Vault Secret Management Library"
date: 2025-12-07
draft: false
tags: ["go", "golang", "shell-scripting", "zsh", "secret-management", "bitwarden", "1password", "pass", "vault-abstraction", "dotfiles", "cli-tools"]
description: "How we evolved from a Bitwarden-only shell script to a production-ready Go library supporting Bitwarden, 1Password, and pass. Learn about vault abstraction patterns, backend interfaces, and why we rewrote 611 lines of Zsh into idiomatic Go."
summary: "Started with hardcoded Bitwarden scripts. Needed to support 1Password and pass. Built a shell abstraction layer, then ported it to Go. Now: one interface, three backends, 95.5% test coverage, zero breaking changes."
---

Your shell scripts hardcode `bw get item`. Your teammate uses 1Password. Your Linux server only has `pass`. You need three completely different implementations.

Here's how we built a vault abstraction layer that works with all three—first in shell, then in Go—without breaking a single existing script.

## The Problem: One Backend, Zero Flexibility

We started with dotfiles that restored secrets from Bitwarden:

```bash
# vault/restore-ssh.sh (the old way)
session=$(bw unlock --raw)
notes=$(bw get item "SSH-GitHub" --session "$session" | jq -r '.notes')
echo "$notes" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

This worked perfectly—until reality hit:

- **Teammate joined**: Uses 1Password (`op`) for corporate policy reasons
- **CI/CD pipeline**: Needed `pass` for simple file-based secrets
- **Air-gapped servers**: No cloud vault access, `pass` with git-sync only

We had three choices:

1. **Maintain three separate scripts** for every vault operation (restore-ssh-bitwarden.sh, restore-ssh-1password.sh, etc.)
2. **Force everyone to use Bitwarden** (not happening)
3. **Build an abstraction layer** that makes vault choice invisible to consumers

## The Solution: Shell Abstraction Layer

We chose option 3. The key insight: **all three vaults do the same things**—store, retrieve, list, sync. They just have different CLIs.

### Interface-First Design

We defined 14 operations every backend must support (`vault/backends/_interface.md`):

```bash
# Authentication
vault_backend_login_check()
vault_backend_get_session()

# Item Operations
vault_backend_get_item(name, session)
vault_backend_get_notes(name, session)
vault_backend_item_exists(name, session)
vault_backend_list_items(session)

# Mutations
vault_backend_create_item(name, content, session)
vault_backend_update_item(name, content, session)
vault_backend_delete_item(name, session)

# Sync
vault_backend_sync(session)
```

### Backend Switching in One Line

The abstraction layer (`lib/_vault.sh`, 611 lines) loads backends dynamically:

```bash
# Get backend from: config file > env var > default
DOTFILES_VAULT_BACKEND="$(_get_configured_backend)"  # → "bitwarden"
VAULT_BACKENDS_DIR="$DOTFILES_DIR/vault/backends"

# Load backend implementation
vault_load_backend() {
    local backend="${1:-$DOTFILES_VAULT_BACKEND}"
    source "$VAULT_BACKENDS_DIR/${backend}.sh"
}

# Use unified API (backend-agnostic)
vault_get_notes() {
    local name="$1"
    local session="$(vault_get_session)"
    vault_backend_get_notes "$name" "$session"
}
```

Now the restore script becomes backend-agnostic:

```bash
# vault/restore-ssh.sh (the new way)
source "$DOTFILES_DIR/lib/_vault.sh"

session=$(vault_get_session)              # Works with any backend
notes=$(vault_get_notes "SSH-GitHub" "$session")
echo "$notes" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

**Zero changes to restore-ssh.sh** when someone switches from Bitwarden to 1Password. Just set `DOTFILES_VAULT_BACKEND=1password` and it works.

### Backend Implementation Example

Each backend implements the interface. Here's how Bitwarden handles session management:

```bash
# vault/backends/bitwarden.sh
vault_backend_get_session() {
    local session=""
    local session_file="$DOTFILES_DIR/vault/.vault-session"

    # Try cached session
    if [[ -f "$session_file" ]]; then
        session="$(cat "$session_file")"
    fi

    # Validate existing session
    if [[ -n "$session" ]] && BW_SESSION="$session" bw unlock --check >/dev/null 2>&1; then
        echo "$session"
        return 0
    fi

    # Need to unlock
    session="$(bw unlock --raw)"

    # Cache with secure permissions
    (umask 077 && printf '%s' "$session" > "$session_file")
    echo "$session"
}

vault_backend_get_notes() {
    local name="$1"
    local session="$2"
    BW_SESSION="$session" bw get item "$name" | jq -r '.notes'
}
```

The `pass` backend looks completely different (no sessions, directory-based), but the **interface is identical**:

```bash
# vault/backends/pass.sh
vault_backend_get_session() {
    # pass uses gpg-agent, no session needed
    echo ""
}

vault_backend_get_notes() {
    local name="$1"
    local prefix="${DOTFILES_VAULT_PREFIX:-dotfiles}"
    pass show "$prefix/$name"
}
```

Consumer code never knows which backend it's talking to.

## Why Port to Go?

The shell version worked great. But we hit limitations:

### 1. Performance

Shell scripts spawn processes constantly:

```bash
# Every call spawns: zsh → bw → jq → zsh
for key in "SSH-GitHub" "SSH-GitLab" "SSH-Work"; do
    notes=$(vault_get_notes "$key" "$session")  # 3 processes each
    # ... restore key ...
done
```

**10-50x slower** than native Go code. Dotfiles installation with 15 secrets took ~30 seconds. Users complained about slow restores.

### 2. Testability

Shell unit tests exist (we use `bats`), but they're clunky:

```bash
# test/vault.bats
@test "vault_get_notes returns item notes" {
    export DOTFILES_VAULT_BACKEND=mock
    result=$(vault_get_notes "test-item")
    [ "$result" = "expected-notes" ]
}
```

No mocking framework. No type safety. No coverage tools. We had ~60% coverage and couldn't easily improve it.

### 3. Error Handling

Shell error handling is primitive:

```bash
vault_backend_get_item() {
    local output
    output=$(bw get item "$name" 2>&1)
    if [[ $? -ne 0 ]]; then
        # Is this "not found" or "session expired" or "network error"?
        # Parse error string to find out (brittle)
        if [[ "$output" =~ "Not found" ]]; then
            return 1
        fi
        # ...
    fi
}
```

Go has proper error types:

```go
if err := backend.GetItem(ctx, name, session); err != nil {
    if errors.Is(err, vaultmux.ErrNotFound) {
        // Handle not found
    } else if errors.Is(err, vaultmux.ErrSessionExpired) {
        // Re-authenticate
    }
}
```

### 4. Distribution

Shell scripts require:
- Correct shell (zsh, not bash)
- Vault CLIs installed (`bw`, `op`, `pass`)
- GNU tools (`jq`, `grep`, `sed`)
- Correct PATH setup

Go compiles to a single binary. Ship `dotfiles-go` and it works (still shells out to vault CLIs, but handles all coordination).

## The Go Implementation: Vaultmux

We ported the shell abstraction to Go as a standalone library: [github.com/blackwell-systems/vaultmux](https://github.com/blackwell-systems/vaultmux)

### Same Interface, Better Types

Shell had 14 functions. Go has one interface:

```go
type Backend interface {
    // Metadata
    Name() string

    // Lifecycle
    Init(ctx context.Context) error
    Close() error

    // Authentication
    IsAuthenticated(ctx context.Context) bool
    Authenticate(ctx context.Context) (Session, error)

    // Item operations
    GetItem(ctx context.Context, name string, session Session) (*Item, error)
    GetNotes(ctx context.Context, name string, session Session) (string, error)
    ItemExists(ctx context.Context, name string, session Session) (bool, error)
    ListItems(ctx context.Context, session Session) ([]*Item, error)

    // Mutations
    CreateItem(ctx context.Context, name, content string, session Session) error
    UpdateItem(ctx context.Context, name, content string, session Session) error
    DeleteItem(ctx context.Context, name string, session Session) error

    // Sync
    Sync(ctx context.Context, session Session) error
}
```

### Backend Registration Pattern

Shell dynamically sources files. Go uses init registration to avoid import cycles:

```go
// backends/bitwarden/bitwarden.go
package bitwarden

import "github.com/blackwell-systems/vaultmux"

func init() {
    vaultmux.RegisterBackend(vaultmux.BackendBitwarden, func(cfg vaultmux.Config) (vaultmux.Backend, error) {
        return New(cfg.Options, cfg.SessionFile)
    })
}
```

Consumer just imports the backend package:

```go
import (
    "github.com/blackwell-systems/vaultmux"
    _ "github.com/blackwell-systems/vaultmux/backends/bitwarden"  // Registers itself
)

func main() {
    backend, err := vaultmux.New(vaultmux.Config{
        Backend: vaultmux.BackendBitwarden,
    })
    // Backend is loaded via factory
}
```

### Session Management with Types

Shell had string sessions:

```bash
session=$(vault_backend_get_session)  # Just a string token
vault_backend_get_notes "item" "$session"
```

Go has a proper Session interface:

```go
type Session interface {
    Token() string
    IsValid(ctx context.Context) bool
    Refresh(ctx context.Context) error
    ExpiresAt() time.Time
}

type bitwardenSession struct {
    token   string
    expires time.Time
    backend *Backend
}

func (s *bitwardenSession) IsValid(ctx context.Context) bool {
    if time.Now().After(s.expires) {
        return false
    }
    // Verify with backend
    cmd := exec.CommandContext(ctx, "bw", "unlock", "--check")
    return cmd.Run() == nil
}
```

### Context-Aware Operations

Shell has no timeout mechanism. Go uses `context.Context` everywhere:

```go
// Timeout after 30 seconds
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

notes, err := backend.GetNotes(ctx, "SSH-Config", session)
if err != nil {
    if ctx.Err() == context.DeadlineExceeded {
        return fmt.Errorf("vault operation timed out")
    }
    return err
}
```

The shell equivalent requires manual timeout wrappers and signal handling.

### Testing with Mocks

Go makes testing trivial:

```go
// mock/mock.go - Included in library
type Backend struct {
    items map[string]string
    GetError error  // Inject errors for testing
}

func (m *Backend) GetNotes(ctx context.Context, name string, session Session) (string, error) {
    if m.GetError != nil {
        return "", m.GetError
    }
    if notes, ok := m.items[name]; ok {
        return notes, nil
    }
    return "", vaultmux.ErrNotFound
}

// In your tests
func TestRestoreSSH(t *testing.T) {
    backend := mock.New()
    backend.SetItem("SSH-GitHub", "fake-private-key")

    // Test your restore logic without real vault
}
```

We went from **~60% shell coverage** to **95.5% Go coverage** (core library). The mock backend itself has 100% coverage.

## Side-by-Side Comparison

### Getting Notes (Shell)

```bash
vault_get_notes() {
    local name="$1"
    local session="$(vault_get_session)"

    if [[ -z "$session" ]]; then
        fail "Not authenticated to vault"
        return 1
    fi

    vault_backend_get_notes "$name" "$session"
}
```

**Lines:** ~10 (excluding backend implementation)
**Error handling:** String comparison
**Type safety:** None
**Timeout:** Manual with `timeout` command

### Getting Notes (Go)

```go
func (c *Client) GetNotes(ctx context.Context, name string) (string, error) {
    session, err := c.backend.Authenticate(ctx)
    if err != nil {
        return "", fmt.Errorf("authentication failed: %w", err)
    }

    notes, err := c.backend.GetNotes(ctx, name, session)
    if err != nil {
        return "", fmt.Errorf("get notes failed: %w", err)
    }

    return notes, nil
}
```

**Lines:** ~12
**Error handling:** Typed errors with `errors.Is()`
**Type safety:** Full static typing
**Timeout:** Built-in via `context.Context`

## Performance Results

Restoring 15 secrets on macOS:

| Implementation | Time | Speedup |
|----------------|------|---------|
| Shell (zsh + jq) | 28.4s | 1x |
| Go (vaultmux) | 1.2s | **23.6x faster** |

The Go version:
- Spawns fewer processes (executes vault CLI once per item, no jq)
- Uses native JSON parsing (encoding/json)
- Caches session validation (no redundant checks)

## Production Results

After shipping vaultmux v0.1.0:

- **Zero breaking changes** to existing shell scripts (they still use `lib/_vault.sh`)
- **Three supported backends** with identical API (Bitwarden, 1Password, pass)
- **95.5% test coverage** on core library (100% on mock)
- **Standalone library** that anyone can use: `go get github.com/blackwell-systems/vaultmux`
- **Extensible by third parties** via [EXTENDING.md](https://github.com/blackwell-systems/vaultmux/blob/main/EXTENDING.md) guide

Our dotfiles now use both:
- **Shell scripts** for interactive operations (setup wizard, drift detection)
- **Go binary** for performance-critical paths (bulk restore, CI/CD)

The two implementations share the same backend interface design. A shell script calling `vault_get_notes` and a Go program calling `backend.GetNotes()` hit the exact same `bw` command under the hood.

## Lessons Learned

### 1. Interface-First Design Pays Off

Defining the 14-operation interface before implementing any backend saved us months. When we ported to Go, the interface translated 1:1. No architectural surprises.

### 2. Shell Scripts Are Underrated

Shell abstraction worked in production for 6 months before we needed Go. Don't jump to Go prematurely—shell scripts with good design can scale further than you think.

But when performance or testability become blockers, Go is the right rewrite target.

### 3. Backend CLIs Are the Source of Truth

We could have reimplemented Bitwarden's API in Go (talking to their server directly). We chose to shell out to `bw` instead.

Why? **The CLI is battle-tested.** Bitwarden handles auth, encryption, edge cases, API changes. We just coordinate the CLI. Our library is ~300 lines per backend instead of ~3,000.

### 4. Don't Break the World

Shipping the Go rewrite as a **separate library** (vaultmux) instead of replacing shell scripts in-place meant:
- Existing users saw zero breakage
- We could iterate on the Go version independently
- Shell and Go could coexist during transition (strangler fig pattern)

This is how you ship architectural rewrites in production.

## When to Use Each

**Use shell abstraction (`lib/_vault.sh`) when:**
- You need interactive prompts (setup wizards)
- Performance doesn't matter (one-time operations)
- You want maximum portability (any Unix with zsh)

**Use Go library (vaultmux) when:**
- Performance matters (bulk operations, CI/CD)
- Type safety helps (complex logic)
- You need comprehensive tests (>90% coverage)

In our dotfiles, both coexist. The shell scripts still work, and they're not going anywhere. The Go rewrite is additive, not disruptive.

## Try It

The Go library is open source and ready to use:

```bash
go get github.com/blackwell-systems/vaultmux
```

Example:

```go
package main

import (
    "context"
    "fmt"
    "log"
    "github.com/blackwell-systems/vaultmux"
    _ "github.com/blackwell-systems/vaultmux/backends/pass"
)

func main() {
    ctx := context.Background()

    backend, _ := vaultmux.New(vaultmux.Config{
        Backend: vaultmux.BackendPass,
    })
    defer backend.Close()

    backend.Init(ctx)
    session, _ := backend.Authenticate(ctx)

    secret, _ := backend.GetNotes(ctx, "API-Key", session)
    fmt.Println("Secret:", secret)
}
```

See the [extension guide](https://github.com/blackwell-systems/vaultmux/blob/main/EXTENDING.md) if you want to add a new backend (HashiCorp Vault, AWS Secrets Manager, etc.).

---

**Code:** [github.com/blackwell-systems/vaultmux](https://github.com/blackwell-systems/vaultmux)
**Shell version:** [github.com/blackwell-systems/dotfiles](https://github.com/blackwell-systems/dotfiles) (lib/_vault.sh)
**Docs:** [Extension guide](https://github.com/blackwell-systems/vaultmux/blob/main/EXTENDING.md)
**License:** MIT
