---
title: "Bulletproof SSH: Multi-Identity Git, Socket Persistence, and Zero-Trust Key Management"
date: 2026-02-25
draft: false
tags: ["ssh", "git", "security", "devops", "github", "identity-management", "openssh", "ssh-config", "ssh-agent", "unix-domain-sockets", "ed25519", "git-config", "multi-identity", "ssh-keys", "control-sockets", "known-hosts", "developer-tools", "dotfiles", "containers", "docker", "linux", "macos"]
categories: ["developer-tools"]
description: "A complete SSH setup for developers juggling personal, business, and enterprise GitHub identities -- using only OpenSSH, git, and coreutils. Host aliases, conditional git configs, control sockets, and known_hosts pinning."
summary: "Most developers cargo-cult their SSH config from Stack Overflow. This is the setup I actually run: three GitHub identities on one machine, persistent control sockets, conditional git configs that auto-select the right key, and pinned known_hosts. No third-party tools."
---

Most developers have an SSH config that grew by accretion. A key here, a host entry there, a Stack Overflow snippet pasted in 2019 that nobody remembers the purpose of. It works until it doesn't -- and when it doesn't, the failure mode is silent: the wrong key gets offered, the wrong email lands on a commit, or an agent helpfully sends your employer's key to your personal project.

This is the setup I actually run. Three GitHub identities on one machine, persistent multiplexed connections, conditional git configuration that auto-selects the right identity, and pinned host keys. Everything uses OpenSSH, git, and coreutils. No third-party tools, no wrapper scripts, no GUI key managers.

## Fundamentals

SSH authentication is built on public key cryptography. You generate a key pair: a private key that stays on your machine, and a public key that you upload to servers you want to access. The two keys are mathematically linked -- data signed with the private key can only be verified by the corresponding public key, and vice versa. When you connect to a server, it sends a random challenge. Your SSH client signs that challenge with your private key and sends the signature back. The server verifies the signature against the public key you registered earlier. If it matches, you're authenticated. The private key itself never crosses the network.

This is why the private key must be protected and the public key can be shared freely. Anyone with your public key can verify your signatures, but only someone holding the private key can produce them. The entire security model collapses if the private key is readable by anyone else -- which is why SSH refuses to use keys with loose file permissions, and why copying private keys into containers or git repositories is dangerous.

When you run `ssh github.com`, OpenSSH doesn't just open a connection to that hostname. It first reads `~/.ssh/config` and searches for a `Host` block that matches the name you typed. If it finds `Host github.com`, it applies every directive in that block -- which key to use, which user to connect as, whether to reuse an existing connection. If no block matches, OpenSSH falls back to defaults. The name you type doesn't have to be a real hostname. `Host github-business` is just a label -- a pattern that OpenSSH matches against. The actual hostname to connect to comes from the `HostName` directive inside that block. This is the mechanism that makes the entire multi-identity setup work: you invent names, map them to the same server, and attach different keys to each name.

The third primitive is process inheritance. When a process starts a child process, the child inherits a copy of the parent's environment variables. Your terminal emulator starts a shell, and that shell inherits variables like `PATH`, `HOME`, and `SSH_AUTH_SOCK`. When you open a new terminal pane or tab, the new shell inherits the same variables from the same parent. When git spawns an SSH subprocess to push code, that subprocess inherits `SSH_AUTH_SOCK` from the shell that ran `git push`. This chain of inheritance is what allows a single SSH agent -- one process, listening on one socket -- to serve every terminal pane, every IDE background process, and every git hook on your system. They all inherited the same `SSH_AUTH_SOCK` value, so they all connect to the same agent.

### How the Pieces Fit Together

{{< mermaid >}}
flowchart TB
    subgraph dev["Developer Machine"]
        direction TB
        subgraph trigger["Git Operation"]
            push["git push"]
            gitcfg[".git/config<br/>remote = git@github-business:org/repo"]
        end

        subgraph identity["Identity Resolution"]
            gitrc["~/.gitconfig<br/>includeIf gitdir:~/code/business/<br/>→ loads business email + sshCommand"]
            sshcfg["~/.ssh/config<br/>Host github-business<br/>→ HostName github.com<br/>→ IdentityFile id_ed25519_business<br/>→ IdentitiesOnly yes"]
        end

        subgraph agent["SSH Agent (single process)"]
            sock["Unix domain socket<br/>SSH_AUTH_SOCK"]
            keys["Decrypted keys in memory<br/>id_ed25519<br/>id_ed25519_business<br/>id_ed25519_enterprise"]
        end

        subgraph ctrl["Control Socket"]
            csock["~/.ssh/sockets/git@github.com-22<br/>Reuses existing connection<br/>if alive"]
        end
    end

    subgraph remote["GitHub"]
        gh["Receives signature<br/>Maps key → account<br/>Authenticates as business identity"]
    end

    push --> gitcfg
    gitcfg --> gitrc
    gitrc --> sshcfg
    sshcfg --> sock
    sock --> keys
    keys -->|"Signs challenge<br/>(private key never leaves agent)"| csock
    csock -->|"Encrypted channel"| gh

    style dev fill:#252627,stroke:#6b7280,color:#f0f0f0
    style trigger fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style identity fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style agent fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style ctrl fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style remote fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style push fill:#3A4A5C,stroke:#5B8AAF,color:#f0f0f0
    style gitcfg fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style gitrc fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style sshcfg fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style sock fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style keys fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style csock fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style gh fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

Here's what happens in time when you run `git push` in a business repo:

{{< mermaid >}}
sequenceDiagram
    participant Dev as Developer
    participant Git as git
    participant GitCfg as ~/.gitconfig
    participant SSH as SSH Client
    participant SSHCfg as ~/.ssh/config
    participant Agent as ssh-agent
    participant Ctrl as Control Socket
    participant GH as GitHub

    Dev->>Git: git push
    Git->>GitCfg: Which identity for this directory?
    GitCfg-->>Git: includeIf matches ~/code/business/<br/>email = you@company.com<br/>sshCommand = use id_ed25519_business
    Git->>SSH: Connect to github-business
    SSH->>SSHCfg: Resolve Host github-business
    SSHCfg-->>SSH: HostName github.com<br/>IdentityFile id_ed25519_business<br/>IdentitiesOnly yes
    SSH->>Ctrl: Existing connection for git@github.com-22?
    alt Control socket alive
        Ctrl-->>SSH: Reuse encrypted channel
    else No socket
        SSH->>GH: TCP + key exchange + host verification
        Note over SSH,GH: New control socket created
    end
    GH->>SSH: Authentication challenge
    SSH->>Agent: Sign challenge with id_ed25519_business
    Agent-->>SSH: Signature (private key stays in agent)
    SSH->>GH: Signed response
    GH-->>Git: Authenticated as business account
    Git-->>Dev: Push complete
{{< /mermaid >}}

The rest of this article walks through each layer -- from the host aliases that select the right key, through the git config that selects the right email, down to the agent and control sockets that handle the actual cryptography and connection management.

## One Host, Multiple Identities

GitHub authenticates by SSH key, not by username. When you `git push`, GitHub looks at which key you presented and maps it to an account. If you have three keys for three GitHub identities (personal, business, enterprise), OpenSSH has no way to know which one to send -- unless you tell it.

The default behavior is worse than random: `ssh-agent` offers keys in the order they were added. If your enterprise key was added first, every `git push` to your personal repo tries the enterprise key. GitHub rejects it (wrong account), and you get `Permission denied`. Or worse: if the enterprise key happens to have access to a shared org, the push succeeds under the wrong identity and the wrong email lands in the commit log.

## Host Aliases with Identity Isolation

```ssh-config
# ~/.ssh/config

# Enterprise (SSO-managed key)
Host github-enterprise
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_enterprise
  IdentitiesOnly yes
  AddKeysToAgent yes

# Business (your company's GitHub org)
Host github-business
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_business
  IdentitiesOnly yes

# Personal (default)
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

Three entries, all pointing at `github.com`, each selecting a different key. The critical directive is `IdentitiesOnly yes` -- without it, OpenSSH still offers every key in the agent before falling back to the configured one. With it, only the specified `IdentityFile` is tried.

Clone a personal repo normally:

```bash
git clone git@github.com:you/personal-project.git
```

Clone a business repo using the alias:

```bash
git clone git@github-business:your-org/internal-tool.git
```

Clone an enterprise repo:

```bash
git clone git@github-enterprise:enterprise-org/platform.git
```

The remote URL embeds the identity. Every subsequent `git pull` and `git push` on that clone uses the correct key automatically, because the remote is stored in `.git/config` as `github-business:...` or `github-enterprise:...`, and SSH resolves those aliases through `~/.ssh/config`.

### Key Generation

Use Ed25519 for all new keys. Ed25519 keys are derived from elliptic curve cryptography over Curve25519, which gives them two practical advantages over RSA: the keys are much shorter (68 characters for a public key vs 400+ for RSA 4096), and signing operations are faster. The security margin is also better -- Ed25519 provides roughly 128 bits of security, equivalent to RSA 3072, but without the risk of weak random number generation that has historically plagued RSA key generation.

Generate one key per identity:

```bash
ssh-keygen -t ed25519 -C "personal@example.com" -f ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -C "you@company.com" -f ~/.ssh/id_ed25519_business
ssh-keygen -t ed25519 -C "you@enterprise.com" -f ~/.ssh/id_ed25519_enterprise
```

The `-f` flag specifies the output file path, which is what makes the multi-identity setup work -- each key pair lives at a distinct path that the SSH config references by name. Without `-f`, `ssh-keygen` defaults to `~/.ssh/id_ed25519` and prompts to overwrite if it already exists.

The `-C` comment is metadata embedded in the public key file. It doesn't affect authentication at all -- servers never see it during the handshake. But it makes `ssh-add -l` output readable when you're debugging which keys are loaded. Without comments, you'll see three identical `ED25519` entries with no way to tell which is which, short of comparing fingerprints manually.

## Conditional Git Config by Directory

Host aliases solve the SSH side, but git also stamps every commit with a name and email. If you forget to set `user.email` in a work repo, your personal email ends up in the enterprise commit log.

Git's `includeIf` directive conditionally loads a config file based on the repo's filesystem path:

```ini
# ~/.gitconfig

[user]
    name = Your Name
    email = personal@example.com

[core]
    editor = nano
    autocrlf = input

# Override identity for all repos under ~/code/enterprise/
[includeIf "gitdir:~/code/enterprise/"]
    path = ~/.gitconfig-enterprise

[credential]
    helper = osxkeychain
```

The enterprise override:

```ini
# ~/.gitconfig-enterprise

[user]
    name = Your Name
    email = you@enterprise.com

[core]
    sshCommand = "ssh -i ~/.ssh/id_ed25519_enterprise -o IdentitiesOnly=yes"
```

Now every repo under `~/code/enterprise/` automatically uses the enterprise email and SSH key, even if the remote URL uses plain `github.com` instead of a host alias. The `core.sshCommand` override is the belt to the host alias's suspenders: it forces the correct key regardless of how the remote was originally cloned.

### Why Both Host Aliases and `sshCommand`?

They solve different problems. Host aliases work when you control the clone URL. `sshCommand` works when you don't -- when someone sends you a clone command, when CI generates remotes, when you `git remote add` without thinking. The `includeIf` path check catches repos by location, so even a plain `github.com` remote in an enterprise directory gets the right key.

Use host aliases as the primary mechanism. Use `sshCommand` as the safety net for repos that slipped through.

## The SSH Agent and Unix Domain Sockets

Before getting into connection multiplexing, it's worth understanding the mechanism underneath it -- and underneath SSH agent forwarding, and underneath the container sharing trick we'll use later. That mechanism is the Unix domain socket.

A Unix domain socket is a file on disk that two processes use to talk to each other. Unlike TCP sockets, which send data over a network (even if both processes are on the same machine), Unix domain sockets use the kernel's file I/O path directly. There's no IP address, no port number, no network stack overhead. One process creates the socket file, and other processes connect to it by path -- the same way they'd open any file, except instead of reading bytes, they get a bidirectional communication channel.

The SSH agent (`ssh-agent`) uses this mechanism to hold your decrypted private keys in memory. When you run `ssh-add ~/.ssh/id_ed25519`, the agent reads the key file, decrypts it (prompting for your passphrase if needed), and stores the raw key material in its own process memory. It then listens on a Unix domain socket -- the path stored in the `SSH_AUTH_SOCK` environment variable.

When any SSH client on the system needs to authenticate, it doesn't read the private key file itself. Instead, it connects to the agent's socket and says "sign this challenge with key X." The agent performs the cryptographic operation and returns the signature. The private key bytes never leave the agent process -- the SSH client only ever sees the signature.

This matters because your development environment isn't one process -- it's dozens. Every terminal pane in tmux or your terminal emulator is a separate shell process. Your IDE runs background processes for git integration, linting, and remote development. Pre-commit hooks spawn their own subprocesses. A `git push` triggered from a VS Code button, a `git fetch` running in a background terminal tab, and an `ssh` command you type manually are all independent processes that need to authenticate with the same keys.

Without the agent, each of these processes would need to read the private key file directly and decrypt it independently. That means either storing keys without passphrases (insecure) or typing your passphrase every time any process touches SSH (unusable). The agent solves this by acting as a single point of contact: all those processes inherit the `SSH_AUTH_SOCK` environment variable from their parent shell, connect to the same socket, and share the same pool of decrypted keys.

This also explains why the socket file's permissions matter. Any process that can connect to the agent's socket can request signatures -- that's the whole point. On a single-user workstation, this is exactly what you want. But it's also what makes agent forwarding across containers and VMs possible: mount the socket file into a container, and processes inside the container can request signatures from the host's agent without ever seeing the key files themselves.

The `AddKeysToAgent yes` directive in your SSH config automates the `ssh-add` step. The first time you use a key (and enter its passphrase), SSH automatically adds it to the agent. Subsequent connections reuse the cached key without prompting. This means you type your passphrase once per session, not once per `git push`.

## Control Socket Persistence

Every `git fetch`, `git pull`, and `git push` opens a new SSH connection. TCP handshake, key exchange, authentication -- repeated for every operation. On high-latency networks or when doing rapid git operations, this adds up.

SSH control sockets use the same Unix domain socket mechanism as the agent, but for a different purpose: multiplexing connections. Instead of holding keys, a control socket represents an open SSH connection. The first SSH invocation to a given host creates the socket; subsequent invocations connect to it and piggyback on the existing encrypted channel:

```ssh-config
# ~/.ssh/config (add to the top, applies to all hosts)

Host *
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
```

`ControlMaster auto` tells OpenSSH to create a master connection if one doesn't exist, or reuse an existing one. The `auto` part is important -- it means every SSH invocation checks for an existing socket first, and only opens a new TCP connection if none is found. You never have to think about it.

`ControlPath` specifies where to store the Unix domain socket that represents the master connection. The `%r@%h-%p` template expands to `git@github.com-22`, so each unique combination of remote user, host, and port gets its own socket file. This matters because a connection to `github.com` as `git` is different from a connection to `github.com` as `admin` -- they authenticate differently and shouldn't share a channel.

`ControlPersist 600` keeps the master connection alive for 10 minutes after the last session using it disconnects. Without this, the master dies the moment the first SSH session exits, and the next `git push` has to negotiate a fresh connection. Ten minutes is long enough to cover a typical edit-commit-push cycle without leaving orphaned connections running for hours.

The socket directory needs to exist before any of this works:

```bash
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
```

The `chmod 700` isn't optional. Control sockets are Unix domain sockets -- files on disk that any process with write access to the directory can connect to. If another user on the system can write to your sockets directory, they can inject commands into your SSH sessions. The `~/.ssh/` directory itself should also be `700` for the same reason.

The performance difference is significant. The first `git push` to a repo requires the full SSH handshake: TCP three-way handshake, key exchange, host verification, and public key authentication -- roughly 200ms on a fast connection, 1-2 seconds over a VPN. The second `git push` within 10 minutes skips all of that and reuses the existing encrypted channel, dropping to around 5ms. This becomes dramatic when running `git fetch --all` across a dozen remotes or doing rapid push-pull cycles during code review.

### Caveats

{{< callout type="warning" >}}
Control sockets persist authentication state. If you `ssh-add -D` to clear your agent but a control socket is still alive, connections through that socket continue to work. The socket dies after `ControlPersist` seconds, but if you need to immediately revoke access, kill the master explicitly.
{{< /callout >}}

```bash
ssh -O exit -o ControlPath=~/.ssh/sockets/%r@%h-%p git@github.com
```

## Pinning Known Hosts

The default `known_hosts` behavior is trust-on-first-use (TOFU). The first time you connect to a host, SSH presents the server's public key fingerprint and asks you to verify it. In practice, everyone types "yes" without checking -- the fingerprint is a 43-character base64 string, and there's no obvious way to verify it in the moment. SSH then saves the key, and every subsequent connection verifies against that saved copy.

TOFU is better than no verification at all, but it has a real gap: the first connection is completely unverified. If an attacker intercepts that first connection -- through DNS poisoning, a compromised network, or a rogue WiFi access point -- they can present their own key, and you'll accept it without knowing. Every connection after that will appear to succeed, because SSH is now verifying against the attacker's key.

For hosts you connect to regularly, you can close this gap by pinning the keys before your first connection. GitHub publishes their SSH host key fingerprints at [github.com/meta](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) -- copy them into your `known_hosts` directly, verified against that page rather than whatever key the server presents on first connect:

```
# ~/.ssh/known_hosts

github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
```

### Hashed Known Hosts

OpenSSH supports hashing hostnames in `known_hosts` so that if someone reads the file, they can't enumerate which hosts you connect to:

```
|1|lAA9c46bP3s8gmZry30/1NfFcOI=|A2naZE3840nECJ3B20MWIWLzDkU= ssh-rsa AAAA...
```

The `|1|` prefix indicates a hashed entry. Enable with `HashKnownHosts yes` in your SSH config. The trade-off: you can't grep the file to see if a host is already known. For personal machines this is minor. For shared jumpboxes, it prevents information leakage.

## File Permissions

SSH is opinionated about file permissions, and its failure mode is the worst kind: silent.

{{< callout type="warning" >}}
If a private key is group-readable, SSH doesn't warn you -- it just skips the key entirely and falls back to the next one. You'll spend an hour debugging why the wrong identity is being offered before you think to check `ls -la`.
{{< /callout >}}

The reason SSH cares is that private keys are the only secret in the entire authentication chain. If another user on the system can read your private key, they can impersonate you to any server that trusts it. SSH enforces this at the filesystem level rather than trusting you to get it right.

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_ed25519*
chmod 644 ~/.ssh/id_ed25519*.pub
chmod 644 ~/.ssh/known_hosts
chmod 700 ~/.ssh/sockets
```

The `700` on `~/.ssh` itself means only you can list, read, or write anything inside it. Private keys get `600` -- owner read/write, no group or world access. Public keys and `known_hosts` can be `644` because they contain no secrets; public keys are literally meant to be shared, and `known_hosts` just records which servers you've connected to.

The config file gets `600` because it can contain sensitive information -- paths to private keys, hostnames of internal infrastructure, port numbers that reveal network topology. On a shared system, even metadata about where you connect is worth protecting.

One common gotcha: if you restore your `.ssh` directory from a backup or copy it from another machine, the permissions often come across wrong. Archive formats don't always preserve Unix permissions, and copying from a FAT32 USB drive or a Windows filesystem sets everything to `755`. Run the `chmod` commands above any time you migrate keys to a new machine.

## Secrets Don't Belong in Repositories

File permissions protect keys on your local machine. But the more common disaster is keys and credentials ending up in git history -- where they're permanent, searchable, and public the moment you push.

This happens more often than people admit. A developer adds a private key or API token to a repo for "just a quick test," forgets about it, and pushes. Even if they delete the file in a subsequent commit, the secret is still in the git history. `git log --all --full-history -- path/to/secret` will find it. GitHub's own secret scanning catches thousands of leaked credentials daily, and that's only the ones that match known patterns.

The rule is simple: secrets never enter version control. Not temporarily, not in a branch you'll delete, not in a private repo you might make public later. Once a secret hits a remote, assume it's compromised and rotate it.

For SSH keys specifically, this means your `~/.ssh` directory lives outside your git repositories entirely. Your `.gitignore` should never need to exclude `id_ed25519` because `id_ed25519` should never be anywhere near a working tree in the first place.

Dotfiles repos are the most common way this goes wrong. Developers version their shell configs, `.gitconfig`, SSH config -- and accidentally include private keys alongside them. A dotfiles repo should contain your `~/.ssh/config` (which has no secrets -- just host aliases and directives) but never your private key files. The same applies to `.env` files, API tokens stored in shell profiles, and anything else that grants access. If your dotfiles repo is public, treat every file in it as public. If it's private, treat every file as one accidental visibility change away from public.

For other secrets -- API keys, database credentials, service account tokens -- the principle extends the same way. Environment variables loaded from a `.env` file that's in `.gitignore` work for local development. For CI/CD, use your platform's secrets management: GitHub Actions secrets, GitLab CI variables, or a dedicated vault. The pattern is always the same: secrets are injected at runtime from a trusted store, never checked into source.

{{< callout type="danger" >}}
If you've already pushed a secret to a remote, deleting the file isn't enough. The secret lives in git history until you rewrite it with `git filter-repo` or BFG Repo-Cleaner -- and even then, anyone who cloned before the rewrite still has it. Rotate the credential immediately. Rewriting history is damage control, not remediation.
{{< /callout >}}

GitHub offers push protection through secret scanning that blocks pushes containing known credential patterns before they reach the remote. Enable it in your repository's security settings. It won't catch everything -- custom API keys or internal tokens don't match GitHub's pattern library -- but it catches the common ones: AWS keys, Slack tokens, database connection strings, and private keys.

For defense in depth, add a pre-commit hook that scans staged files for high-entropy strings or known secret patterns. Tools like `gitleaks` run in milliseconds and catch secrets before they enter local history, let alone a remote. A secret that never gets committed doesn't need to be rotated.

## Sharing Across VM and Container Boundaries

If you develop inside Linux VMs (Lima, Colima, UTM) or containers (Docker, devcontainers), you have the same SSH config problem twice: the host machine has your keys and config, but the guest needs them too.

{{< callout type="danger" >}}
**Never copy private keys into containers.** They end up in image layers, build caches, or container filesystems that outlive the session. Even a `COPY` in a multi-stage build leaves the key in an intermediate layer that `docker history` can extract.
{{< /callout >}}

The clean approach is bind-mounting your host's `~/.ssh` directory into the guest as read-only:

```bash
# Lima/Colima: already handled -- Lima mounts ~/.ssh automatically
# and forwards the host's ssh-agent socket via SSH_AUTH_SOCK.

# Docker run:
docker run -v ~/.ssh:/root/.ssh:ro -v $SSH_AUTH_SOCK:/ssh-agent \
  -e SSH_AUTH_SOCK=/ssh-agent myimage

# Docker Compose:
volumes:
  - ~/.ssh:/root/.ssh:ro
  - ${SSH_AUTH_SOCK}:/ssh-agent
environment:
  - SSH_AUTH_SOCK=/ssh-agent
```

The `:ro` flag is important -- the guest can read your config and keys but can't modify or exfiltrate them through the mount. Agent forwarding via `SSH_AUTH_SOCK` is even better: the guest never sees private key bytes at all, only a socket that can request signatures.

For tools like Colima that generate their own SSH config (for talking to the VM itself), OpenSSH's `Include` directive keeps things clean:

```ssh-config
# Top of ~/.ssh/config
Include /path/to/colima/ssh_config
```

The VM's SSH config gets merged into yours without duplication. Your host aliases, control sockets, and identity isolation carry through unchanged -- inside the VM, `git clone git@github-business:org/repo.git` resolves through the same config chain and uses the same key, because the config and agent socket are the same ones.

## All Together

Here's everything assembled into copy-pasteable configs. The SSH config goes in one file, the git configs in two. The order within the SSH config matters: the wildcard `Host *` block goes first so its directives apply as defaults to all subsequent host entries, and the specific host entries follow in any order.

The directory structure:

```
~/.ssh/
├── config              # Host aliases, control sockets
├── sockets/            # Control socket directory
├── known_hosts         # Pinned host keys
├── id_ed25519          # Personal key
├── id_ed25519.pub
├── id_ed25519_business     # Business key
├── id_ed25519_business.pub
├── id_ed25519_enterprise       # Enterprise key
└── id_ed25519_enterprise.pub
```

The full `~/.ssh/config`:

```ssh-config
# Connection multiplexing
Host *
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  AddKeysToAgent yes

# Enterprise (SSO-managed)
Host github-enterprise
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_enterprise
  IdentitiesOnly yes

# Business
Host github-business
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_business
  IdentitiesOnly yes

# Personal (default catch-all for github.com)
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

The `~/.gitconfig` sets personal as the default identity and conditionally overrides for enterprise directories. Add as many `includeIf` blocks as you have identities -- one for business under `~/code/business/`, another for enterprise under `~/code/enterprise/`, and so on:

```ini
[user]
    name = Your Name
    email = personal@example.com

[core]
    editor = nano
    autocrlf = input

[includeIf "gitdir:~/code/enterprise/"]
    path = ~/.gitconfig-enterprise

[credential]
    helper = osxkeychain
```

The `~/.gitconfig-enterprise` overrides both the commit identity and the SSH key. The `sshCommand` here is the safety net for repos cloned with a plain `github.com` remote instead of the `github-enterprise` host alias:

```ini
[user]
    name = Your Name
    email = you@enterprise.com

[core]
    sshCommand = "ssh -i ~/.ssh/id_ed25519_enterprise -o IdentitiesOnly=yes"
```

## Verification

Test each identity:

```bash
ssh -T github.com            # Should greet your personal account
ssh -T github-business       # Should greet your business account
ssh -T github-enterprise     # Should greet your enterprise account
```

Verify the right key is being used (verbose output):

```bash
ssh -vT github-business 2>&1 | grep "Offering"
# Should show only id_ed25519_business
```

Check git identity per repo:

```bash
cd ~/code/enterprise/some-repo
git config user.email
# Should show you@enterprise.com

cd ~/code/personal/some-repo
git config user.email
# Should show personal@example.com
```

Verify control socket is active:

```bash
ssh -O check -o ControlPath=~/.ssh/sockets/%r@%h-%p git@github.com
# Master running (pid=12345)
```

## What This Prevents

The most common SSH failure is wrong-identity commits -- your personal email showing up in the enterprise audit log, or your work identity stamped on an open source contribution. The `includeIf` conditional config eliminates this entirely. Every repo under a given directory tree automatically gets the right name and email, and the `core.sshCommand` override ensures the right key is used even if the remote URL wasn't cloned with a host alias.

Key confusion is the second failure mode. Without `IdentitiesOnly yes`, the SSH agent offers every loaded key to every server, in the order they were added. GitHub accepts the first one that matches any account, and you get a silent identity mismatch. With explicit host aliases and identity isolation, each connection uses exactly one key -- no guessing, no fallback chain, no silent wrong-account authentication.

The third category is silent authentication failures. When SSH falls back through multiple keys and none match, the error message is cryptic at best. Explicit host entries with `IdentitiesOnly yes` mean SSH tries one key and either succeeds or fails clearly. You never have to wonder which key was offered or why the connection was rejected.

Control sockets address pure performance overhead. Repeated SSH handshakes during rapid git operations -- a `fetch`, a `rebase`, a `push`, another `fetch` -- accumulate latency that feels sluggish on VPNs and high-latency connections. Multiplexing eliminates the repeated negotiation entirely after the first connection.

Finally, pinned `known_hosts` entries close the trust-on-first-use gap. The default TOFU behavior means your very first connection to a host is vulnerable to interception. Pinning GitHub's published host keys means you verify identity from the first connection, not just from the second one onward.

None of this requires a key manager, a GUI, or a wrapper script. It's OpenSSH config, git config, and filesystem permissions. The tools you already have.
