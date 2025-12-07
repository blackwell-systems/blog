---
title: "From Shell Scripts to Go: Building a Multi-Vault Secret Management Library"
date: 2025-12-07
draft: false
tags: ["go", "golang", "shell-scripting", "zsh", "secret-management", "bitwarden", "1password", "pass", "vault-abstraction", "dotfiles", "cli-tools"]
description: "We needed multi-vault support without duplicating scripts or breaking existing users—so we designed a vault interface in shell, then ported it 1:1 into Go. Learn about interface-first design, compatibility-preserving rewrites, and when to evolve from shell to Go."
summary: "Started with Bitwarden-only shell scripts. Needed to support 1Password and pass without breaking anything. Built a shell abstraction layer, then ported it to Go. Same interface, three backends, zero breaking changes."
---

We needed multi-vault support without duplicating scripts or breaking existing users—so we designed a vault interface in shell, then ported it 1:1 into Go.

## What We Built

We started with Bitwarden-only shell scripts that restored secrets for our dotfiles. It worked until different environments required different vaults: 1Password for teammates, pass for CI and air-gapped servers. Maintaining parallel scripts for every backend wasn't scalable.

So we built a vault abstraction in shell with a small, consistent interface—then ported that interface 1:1 into Go. The result is [vaultmux](https://github.com/blackwell-systems/vaultmux): a library that keeps vault choice invisible to consumers, improves performance and testability, and lets the shell and Go implementations coexist without breaking existing workflows.

## The Pain: Three Vaults, Zero Portability

Our dotfiles started with hardcoded Bitwarden calls:

```bash
# vault/restore-ssh.sh (the old way)
session=$(bw unlock --raw)
notes=$(bw get item "SSH-GitHub" --session "$session" | jq -r '.notes')
echo "$notes" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

This worked perfectly—until:

- **Teammate joined** using 1Password (`op`) for corporate policy reasons
- **CI/CD pipeline** needed `pass` for file-based secrets without cloud dependencies
- **Air-gapped servers** required `pass` with git-sync (no Bitwarden access)

We had three choices:
1. Maintain separate scripts for every vault (restore-ssh-bitwarden.sh, restore-ssh-1password.sh, etc.)
2. Force everyone onto Bitwarden (not happening)
3. Build an abstraction that makes vault choice transparent

## The Insight: Shared Operations

**All three vaults do the same things**—store, retrieve, list, sync. They just have different CLIs.

That's the click.

If we define a common interface for those operations, consumer code never needs to know which vault it's using. The backend becomes a configuration choice, not a fork in the code.

## The Shell Interface

We defined the operations every backend must support. Here's the core:

```bash
# Authentication
vault_backend_get_session()

# Read operations
vault_backend_get_notes(name, session)
vault_backend_list_items(session)

# Write operations
vault_backend_create_item(name, content, session)
vault_backend_update_item(name, content, session)
```

(Full interface: 14 operations covering authentication, CRUD, sync, and location management—see [_interface.md](https://github.com/blackwell-systems/dotfiles/blob/main/vault/backends/_interface.md))

The abstraction layer (~600 lines in `lib/_vault.sh`) loads backends dynamically:

```bash
# Get backend from: config file > env var > default
DOTFILES_VAULT_BACKEND="$(_get_configured_backend)"

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

## What We Gained: Zero-Cost Switching

Here's the real magic—switching vaults requires **zero code changes**:

```bash
# Before: using Bitwarden
export DOTFILES_VAULT_BACKEND=bitwarden
dotfiles vault restore

# Later: corp policy requires 1Password
export DOTFILES_VAULT_BACKEND=1password
dotfiles vault restore  # Same command, different vault
```

Consumer code (`restore-ssh.sh`, `restore-aws.sh`, etc.) never changes. The backend is a runtime choice.

Each backend implements the same interface but calls different CLIs:

```bash
# vault/backends/bitwarden.sh
vault_backend_get_notes() {
    local name="$1"
    local session="$2"
    BW_SESSION="$session" bw get item "$name" | jq -r '.notes'
}

# vault/backends/pass.sh
vault_backend_get_notes() {
    local name="$1"
    local prefix="${DOTFILES_VAULT_PREFIX:-dotfiles}"
    pass show "$prefix/$name"
}
```

Bitwarden needs sessions; pass uses gpg-agent. Consumer code never knows the difference.

## Why Shell Hit Its Ceiling

The shell abstraction worked in production for months. But we hit limits:

### Performance: Process Overhead

Shell scripts spawn processes constantly:

```bash
# Every iteration: zsh → bw → jq → zsh
for key in "SSH-GitHub" "SSH-GitLab" "SSH-Work"; do
    notes=$(vault_get_notes "$key" "$session")  # 3 processes each
    # ... restore key ...
done
```

Restoring 15 secrets took ~30 seconds. Users complained.

The win wasn't "Go is magically faster"—it's that **we reduced process churn**. Go spawns the vault CLI once per item (no jq subprocess), uses native JSON parsing, and caches session validation. That dropped restore time to ~1 second (an order-of-magnitude improvement).

### Testability: No Mocking Framework

Shell tests with `bats` exist, but coverage tools are limited. We had ~60% coverage and couldn't easily improve it. No structured mocking, no type safety.

Go's mock backend made testing trivial:

```go
func TestRestoreSSH(t *testing.T) {
    backend := mock.New()
    backend.SetItem("SSH-GitHub", "fake-private-key")
    // Test restore logic without real vault
}
```

We hit >90% coverage in the Go version with comprehensive error scenario tests.

### Error Handling: String Parsing

Shell error handling is brittle:

```bash
output=$(bw get item "$name" 2>&1)
if [[ $? -ne 0 ]]; then
    # Is this "not found" or "session expired"?
    # Parse error strings (fragile)
    if [[ "$output" =~ "Not found" ]]; then
        return 1
    fi
fi
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

## The Go Rewrite: Same Interface, Better Runtime

We ported the shell interface to Go as [vaultmux](https://github.com/blackwell-systems/vaultmux), a standalone library.

### Same 14 Operations, Stronger Types

Shell had 14 functions; Go has one interface:

```go
type Backend interface {
    Name() string
    Init(ctx context.Context) error
    Close() error

    IsAuthenticated(ctx context.Context) bool
    Authenticate(ctx context.Context) (Session, error)

    GetItem(ctx context.Context, name string, session Session) (*Item, error)
    GetNotes(ctx context.Context, name string, session Session) (string, error)
    ListItems(ctx context.Context, session Session) ([]*Item, error)

    CreateItem(ctx context.Context, name, content string, session Session) error
    UpdateItem(ctx context.Context, name, content string, session Session) error
    DeleteItem(ctx context.Context, name string, session Session) error

    Sync(ctx context.Context, session Session) error
}
```

Shell sessions were strings; Go has a proper interface:

```go
type Session interface {
    Token() string
    IsValid(ctx context.Context) bool
    Refresh(ctx context.Context) error
    ExpiresAt() time.Time
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

### Backend Registration Pattern

Shell dynamically sources files. Go uses init registration to avoid import cycles:

```go
// backends/bitwarden/bitwarden.go
func init() {
    vaultmux.RegisterBackend(vaultmux.BackendBitwarden,
        func(cfg vaultmux.Config) (vaultmux.Backend, error) {
            return New(cfg.Options, cfg.SessionFile)
        })
}
```

Consumer just imports backend packages:

```go
import (
    "github.com/blackwell-systems/vaultmux"
    _ "github.com/blackwell-systems/vaultmux/backends/bitwarden"
)

backend, err := vaultmux.New(vaultmux.Config{
    Backend: vaultmux.BackendBitwarden,
})
```

### What "Production-Ready" Means

We shipped vaultmux v0.1.0 with:

- **Stable interface** (no breaking changes planned)
- **Mock backend** included for unit testing
- **Error taxonomy** (`ErrNotFound`, `ErrSessionExpired`, etc.)
- **Context timeouts** on all operations
- **>90% test coverage** on core library

This isn't just "it works on my machine"—it's designed for third parties to depend on.

## The Migration Strategy: Coexistence

Shipping the Go rewrite as a **separate library** instead of replacing shell scripts in-place meant:

- Existing shell users saw zero breakage
- We could iterate on Go independently
- Shell and Go coexist during transition (strangler fig pattern)

Our dotfiles now use both:

- **Shell scripts** for interactive operations (setup wizard, drift detection)
- **Go binary** for performance-critical paths (bulk restore, CI/CD)

The shell script calling `vault_get_notes` and the Go program calling `backend.GetNotes()` hit the same `bw` command under the hood. Same backend CLIs, same behavior, different coordination layers.

## When to Use Which

**Use shell abstraction when:**
- You need interactive prompts (setup wizards)
- Performance doesn't matter (one-time operations)
- Maximum portability matters (any Unix with zsh)

**Use Go library when:**
- Performance matters (bulk operations, CI/CD)
- Type safety helps (complex logic, error scenarios)
- Comprehensive tests are needed (>90% coverage)

In practice, both coexist. Shell scripts aren't going anywhere—the Go version is additive, not disruptive.

## Lessons Learned

### 1. Interface-First Design Transfers

Defining the 14-operation interface before implementing backends saved months. When we ported to Go, the interface translated 1:1. No architectural surprises.

### 2. Shell Scripts Scale Further Than You Think

Shell abstraction worked in production for months before we needed Go. Don't jump to Go prematurely—shell scripts with good design can handle more than you expect.

But when performance or testability become blockers, Go is the right evolution target.

### 3. Shell Out to CLIs, Don't Reimplement

We could have reimplemented Bitwarden's API in Go (talking to their server directly). We chose to shell out to `bw` instead.

Why? **The CLI is battle-tested.** Bitwarden handles auth, encryption, edge cases, API changes. We just coordinate the CLI. Our library is ~300 lines per backend instead of thousands.

### 4. Make Architectural Rewrites Additive

Shipping as a separate library (vaultmux) instead of replacing shell scripts meant zero breakage. This is how you ship architectural changes in production—make them additive, not destructive.

## Get Started

The Go library is open source:

```bash
go get github.com/blackwell-systems/vaultmux
```

Example usage:

```go
package main

import (
    "context"
    "fmt"
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

Want to add a new backend? See the [extension guide](https://github.com/blackwell-systems/vaultmux/blob/main/EXTENDING.md) for HashiCorp Vault, AWS Secrets Manager, etc.

---

**Code:** [github.com/blackwell-systems/vaultmux](https://github.com/blackwell-systems/vaultmux)

**Shell version:** [github.com/blackwell-systems/dotfiles](https://github.com/blackwell-systems/dotfiles) (lib/_vault.sh)

**Docs:** [Extension guide](https://github.com/blackwell-systems/vaultmux/blob/main/EXTENDING.md)

**License:** MIT
