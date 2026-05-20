---
title: "What Git Did for Files, Applied to Code Relationships"
date: 2026-05-20
draft: false
tags: ["git", "content-addressed", "merkle-tree", "code-intelligence", "ai-agents", "mcp", "developer-tools", "knowing", "open-source", "static-analysis", "code-graph", "cryptography"]
categories: ["ai", "architecture", "developer-tools"]
description: "Git versions file contents with SHA-256 hashes and Merkle trees. The same architecture applied to code relationships (who calls what, who depends on what) gives you versioned intelligence: diffs, caching, proofs, and self-healing memory. For free."
summary: "Git proved that content-addressing file contents gives you integrity, history, efficient equality, and distributed collaboration for free. The same architecture applied to code relationships gives you something new: versioned intelligence that you can diff, cache, prove, and trust over time."
---

## The Bet Git Made

In 2005, git made a bet: identify every file by the SHA-1 hash of its contents. Not by path. Not by timestamp. Not by an ID someone assigned. By what it IS.

That single choice gave git:
- **History for free.** Each commit is a hash of a tree of hashes. Walk the chain.
- **Integrity for free.** Recompute the hash. If it matches, nothing was tampered with.
- **Efficient equality for free.** Two repos with the same root hash have the same content. One comparison.
- **Distributed collaboration for free.** No central authority decides IDs. The content IS the identity.
- **Caching for free.** Object X with hash H is valid forever. It can never change (that would change the hash).

None of these were "features" git implemented. They're structural consequences of content-addressing. You get them all by choosing the right identity model.

## What Git Doesn't Version

Git versions file contents. It knows "file auth.go changed in commit abc123." It doesn't know:

- Which functions in auth.go call which functions in store.go
- Whether removing `ValidateToken` breaks 14 callers across 3 packages
- Which HTTP routes are now dead because their handler was deleted
- Whether the billing service can reach the user database (structurally, not just "did it today")
- How the service graph changed between the deploy on Monday and the deploy on Friday

These are relationships between code, not the code itself. Git doesn't version relationships. No tool does.

## The Same Bet, Applied to Relationships

What if you content-addressed code relationships the same way git content-addresses files?

```
Git:     FileHash = SHA-256(file contents)
knowing: EdgeHash = SHA-256("edge\0" + source_hash + target_hash + relationship_type + provenance)
```

A "calls" edge from `CreateOwner` to `OwnerRepository.save` gets a hash derived from what it connects, how, and who discovered it. Same relationship always gets the same hash. Different relationship always gets a different hash.

### Why the domain prefix matters

Notice `"edge\0"` at the start. Without it, a node hash could accidentally collide with an edge hash (different data, same SHA-256 output). The prefix makes collision across types structurally impossible: edge hashes always start with `SHA-256("edge\0" + ...)`, node hashes always start with `SHA-256("node\0" + ...)`. Same principle as git's `"blob <size>\0"` header.

### Worked example

Say `CreateOwner` (hash: `a27e...`) calls `save` (hash: `f891...`). The edge:

```
Input:  "edge\0" + a27eac26... + f891bb04... + "calls" + "ast_inferred"
Output: 7b3c910f4d82a1e5c6...  (the edge's permanent identity)
```

Change anything (different source, different target, different type, different provenance) and the output changes completely. Keep everything the same and the output is identical, on any machine, forever.

### From edges to snapshots

Now do what git does: build a Merkle tree over all the edge hashes. But don't just sort them flat. Group them by semantic boundaries:

```
repo root = merkle(sorted package roots)
  package root [auth] = merkle(sorted edge-type roots for auth)
    edge-type root [auth:calls] = merkle(sorted edge hashes of type "calls" in auth)
      leaf: 7b3c...  (CreateOwner -> save)
      leaf: 91f2...  (CreateOwner -> validate)
      leaf: c44d...  (ListOwners -> findAll)
    edge-type root [auth:imports] = merkle(sorted edge hashes of type "imports" in auth)
      leaf: d55e...  (auth -> repository)
  package root [store] = merkle(sorted edge-type roots for store)
    edge-type root [store:calls] = merkle(sorted edge hashes)
      leaf: e66f...  (save -> db.Exec)
```

Each interior node is `SHA-256("merkle\0" + left_child + right_child)`. Leaves are sorted by `bytes.Compare` before construction, so the root is deterministic regardless of insertion order.

The repo root is the snapshot hash. Like a git commit hash, it summarizes the entire state. Unlike a git commit, it summarizes *relationships*, not files. And the intermediate roots (package roots, edge-type roots) give you granularity git doesn't have.

```
Git:     commit_hash = merkle_root(all file blobs, organized by directory)
knowing: snapshot_hash = merkle_root(all edge hashes, organized by package and type)
```

### Why edges, not nodes

The tree is built from **edges** (relationships), not nodes (symbols). This is deliberate. A node's existence rarely changes: functions get added or removed occasionally. But relationships change constantly: new callers appear, imports shift, runtime traffic patterns evolve, dependencies get added or removed.

Knowing that `CreateOwner` exists tells you almost nothing. Knowing that `CreateOwner` calls `save`, handles `POST /owners/new`, is called by 3 controllers, and was observed 10,000 times in production: that's the intelligence. Edges carry the meaning. Nodes are just anchor points.

Building from edges means "did anything change?" captures: new callers, removed dependencies, changed routes, different runtime traffic. Every downstream operation (diff, cache invalidation, proofs, blast radius) cares about relationships, not symbol existence.

## What You Get For Free

The same five properties git gets, applied to intelligence instead of text:

**1. History for free.**
Each snapshot links to its parent (like commits). "What relationships existed at the deploy on Monday?" is a lookup, not a reconstruction. "When did the dependency between billing and payments first appear?" is a chain walk.

**2. Integrity for free.**
Recompute the Merkle root from the edges. If it matches the stored root, the graph hasn't been tampered with. If it doesn't, something was modified. Verification takes 98ms on a graph with 13,000 edges. Offline. No database needed.

**3. Efficient equality for free.**
"Did anything change?" is one 32-byte comparison. Not a full scan. Not a set difference. One `==` on two hashes. "Did package X specifically change?" is also one comparison (of the package root, not the global root).

**4. Distributed trust for free.**
Two people who independently index the same repo at the same commit get the same snapshot hash. Always. CI and local development produce identical results. "It indexed differently on my machine" is structurally impossible.

**5. Caching for free.**
A query result computed against package root H is valid for all time. The package root is the cache key AND the validity check. No TTLs. No invalidation logic. Changed package = new root = recompute. Unchanged package = same root = cache hit. 83 nanoseconds.

### How a change cascades (worked example)

Someone adds a new function in the `auth` package that calls `validate`. One new edge:

```
Before:
  edge-type root [auth:calls] = merkle(7b3c, 91f2, c44d) = X
  package root [auth] = merkle(X, imports_root) = P
  repo root = merkle(P, store_root) = R

After (new edge ab12 added):
  edge-type root [auth:calls] = merkle(7b3c, 91f2, ab12, c44d) = X'  ← CHANGED
  package root [auth] = merkle(X', imports_root) = P'  ← CHANGED (because X changed)
  repo root = merkle(P', store_root) = R'  ← CHANGED (because P changed)
```

The change cascades up through the tree. But `store_root` is unchanged. Anything cached against `store_root` is still valid. Anything cached against `imports_root` within auth is still valid. Only `auth:calls` and its ancestors need recomputation.

**The diff algorithm:**
1. Compare repo roots: R != R'. Something changed. (One comparison.)
2. Compare package roots: P != P' (auth changed), store == store (store didn't). (One comparison per package.)
3. For changed packages, compare edge-type roots: X != X' (calls changed), imports == imports.
4. Only drill into the changed edge-type to find the specific new edge.

Steps 1-3 are O(packages). Step 4 is O(edges in that one type). Total: proportional to what changed, not to the graph size.

### At scale

These numbers are from real benchmarks on real code, not synthetic tests:

| Graph size | Flat diff (scan all edges) | Hierarchical diff | Speedup |
|---|---|---|---|
| 10K edges (knowing repo) | 540us | 2.2us | 249x |
| 50K edges | 2.9ms | 5.7us | 516x |
| 100K edges | 6.8ms | 12us | 565x |
| 249K edges (Grafana) | ~15ms | ~25us | ~600x |

Build time for the hierarchical tree: 88ms for Grafana's 249K edges (3,552 packages). The 1.4x build overhead vs a flat tree is paid once; every subsequent diff, cache check, and proof generation benefits.

## The Part Git Doesn't Have: Proofs

Git can tell you "this file existed at this commit." It can't prove it to someone who doesn't have the repo.

With code relationships in a Merkle tree, you can generate a **proof**: a path from a specific edge through the tree to the root. Anyone with the proof and the root hash can verify the edge exists. No database. No network. Just SHA-256.

```
knowing prove -source "PaymentService" -target "StripeClient" -type calls -human

INCLUSION PROOF

  Source:     PaymentService
  Target:     StripeClient
  Edge type:  calls
  Snapshot:   f479567d95cc8374...

  Edge hash:       91846fd7bdd29057...
  Package:         github.com/org/repo/internal/payments
  Proof steps:     10 (leaf→edge-type)
                   1 (edge-type→package)
                   6 (package→repo)
  Repo root:       055654260f5f8569...

  VERIFIED: "calls" edge exists from PaymentService to StripeClient
```

16 hash steps. ~660 bytes. Verifiable offline forever.

### What the verifier actually does

The verifier receives: the edge hash, 16 sibling hashes with directions, and the expected root. It executes:

```
current = edge_hash (7b3c...)

Step 1:  current = SHA-256("merkle\0" + current + sibling_1)    # combine with right sibling
Step 2:  current = SHA-256("merkle\0" + sibling_2 + current)    # combine with left sibling
Step 3:  current = SHA-256("merkle\0" + current + sibling_3)
... (10 steps: leaf → edge-type root)

Step 11: current = SHA-256("merkle\0" + sibling_11 + current)   # edge-type → package root
... (1 step: edge-type root → package root)

Step 12: current = SHA-256("merkle\0" + current + sibling_12)
... (6 steps: package root → repo root)

Step 16: assert(current == expected_repo_root)
```

If the final value equals the claimed root: the edge is proven to exist in this tree. If it doesn't: the proof is invalid (the edge was fabricated, the tree was different, or the proof was corrupted).

The verifier needs only: the edge hash, the proof file (~660 bytes), and the expected root. No database. No network. No trust in the prover. Just SHA-256.

Generation time: 72 microseconds. Verification time: 1.2 microseconds (just 16 hash computations). Zero allocations.

### Absence proofs: proving a negative

And the one thing no other system can do:

```
knowing prove-absent -source "PaymentService" -target "UserDB" -type calls -human

ABSENCE PROOF

  Source:     PaymentService
  Target:     UserDB
  Edge type:  calls
  Absent:     true
  Snapshot:   f479567d95cc8374...

  Left neighbor:   62a632e6b01031ff...
  Right neighbor:  630f09d42fe8a4db...

  VERIFIED: No "calls" edge exists from PaymentService to UserDB
```

Prove something does NOT exist. Not "I searched and didn't find it." Mathematical proof.

**How it works:** The leaves at each level are sorted by byte order. If edge X doesn't exist, there are two adjacent leaves A and B such that A < X < B. The proof contains:

1. An inclusion proof for A (proving A is in the tree)
2. An inclusion proof for B (proving B is in the tree)
3. Both against the same root

The verifier checks:
- A's proof verifies against the root (A exists)
- B's proof verifies against the root (B exists)
- A < X < B in byte order (X would be between them)
- A and B are adjacent (no leaf between them in the sorted set)

If all four pass: X cannot exist in this tree. The sorted structure guarantees there's no room for it between its neighbors.

This is the same principle Certificate Transparency uses to prove a certificate was never issued. Applied to code relationships. The difference between "grep didn't find it" (maybe grep missed something) and "mathematically, it cannot be there."

## The Part Git Doesn't Have: Semantic Structure

Git's Merkle tree follows the file system: directories contain files. The tree is organized by WHERE things are stored.

For code relationships, you want the tree organized by WHAT things mean:

```
repo root
  package root [internal/auth]       <- one comparison: "did auth change?"
    edge-type root [auth:calls]      <- one comparison: "did call edges change?"
      edge leaves
    edge-type root [auth:imports]
      edge leaves
  package root [internal/store]      <- unchanged? all store caches still valid
```

This means:
- "Which packages changed?" is O(packages), not O(edges). 565x faster at 100K edges.
- "Did call edges change independently of import edges?" is one root comparison.
- "Is my cached blast-radius for store still valid?" is one root comparison.
- Proof paths are short: edge → edge-type → package → root. Three levels.

The tree doesn't just prove state. It tells you WHERE change happened and WHAT KIND of change it was. Git's tree tells you "something changed in directory X." This tree tells you "call relationships changed in package auth."

## The Part Git Doesn't Have: Learning

Git doesn't learn. The 1000th commit is stored the same way as the 1st. No accumulated wisdom.

With content-addressed relationships, you can add a learning layer. But you have to solve a hard problem first.

### The poisoning problem

Naive persistent feedback degrades over time. Here's why:

- Session 1: Agent works on auth. Marks `ValidateToken` as useful.
- Session 2-50: `ValidateToken` gets boosted in rankings. Good.
- Session 51: Someone rewrites `ValidateToken` completely (new logic, new dependencies, different behavior).
- Session 52+: The old feedback still boosts `ValidateToken`. But the feedback was about the OLD implementation. The signal is now wrong.

Over months, a system that never expires feedback accumulates hundreds of stale signals pointing at rewritten code. Rankings degrade. The system gets WORSE with use, not better.

Solutions people try:
- **TTL (expire after 7 days):** Arbitrary. Throws away valid feedback on stable code.
- **Manual cleanup:** Doesn't scale. Nobody maintains this.
- **Forget everything each session:** Loses all learning. Back to cold start.

### Content-addressed feedback (the solution)

When recording feedback, store the Merkle root of the relevant package alongside the signal:

```
Record feedback:
  symbol_hash:      a27e...  (ValidateToken)
  useful:           true
  neighborhood_root: 9dc3...  (SubgraphRoot of internal/auth RIGHT NOW)
```

When querying feedback later:

```
Query: "What's the feedback on ValidateToken?"

Step 1: Compute current SubgraphRoot of internal/auth = 9dc3...
Step 2: Compare stored root (9dc3) against current root (9dc3)
Step 3: They match. Feedback is valid. Apply the boost.
```

After code changes:

```
Query: "What's the feedback on ValidateToken?"

Step 1: Compute current SubgraphRoot of internal/auth = f891...  (code changed!)
Step 2: Compare stored root (9dc3) against current root (f891)
Step 3: They DON'T match. Feedback expired. Invisible. Don't apply.
```

No TTLs. No manual cleanup. No garbage collection. The Merkle root IS the validity check. If the code is the same, the feedback applies. If the code changed, the feedback disappears.

### Measured impact

Over 5 rounds of feedback on 55 evaluation fixtures:

```
Round 1: 16% precision (cold, no feedback)
Round 2: 36% precision (+20 percentage points, immediate improvement)
Round 3: 44%
Round 4: 48%
Round 5: 50% precision (sustained, no degradation)
```

The improvement is immediate (first round of feedback has the biggest impact) and sustained (doesn't degrade in subsequent rounds because stale feedback self-expires when code changes).

Performance overhead of checking neighborhood roots: 11% (255us → 284us for 100 symbols). Negligible compared to the precision improvement.

### Why this only works with content-addressing

You can't bolt this onto a mutable system. The mechanism relies on:
1. A deterministic root for any set of packages (same code = same root, always)
2. The root changing when ANY edge in the package changes
3. Comparing two 32-byte hashes being O(1)

Without content-addressing, "has this package changed?" requires scanning all its edges, diffing them against the recorded state, and deciding. That's O(edges) per feedback lookup. With content-addressing, it's one hash comparison. The architecture makes the mechanism cheap enough to run on every query.

## The Practical Result

For an AI coding agent, this means:

**Before (grep-read-grep-read):**
1. Read the file you're editing
2. Grep for related symbols
3. Read those files
4. Grep again for callers
5. Read more files
6. Build a mental model from fragments
7. Write code
8. Next turn: forget everything and start over

Six to eight tool calls per turn. 60% of context spent re-reading files from last turn. Relationships that span repos are invisible.

**After (one call to a content-addressed graph):**
- One call returns ranked, relevant symbols
- Cached (83ns) if the code hasn't changed
- Learns what's useful, forgets what's stale
- Blast radius, test scope, diff are primitive operations

Concrete example from knowing's own dogfooding: `BuildHierarchicalTree` has 10+ callers across 5 packages (SnapshotManager, prove commands, audit, feedback, tests). Change its signature? One graph query surfaces all 10 callers instantly. grep would need to find the function name, then chase each call site, then figure out which are actually calls vs comments vs strings. The graph already knows.

For a security team:

**Before:** "grep says nobody calls UserDB from PaymentService"

**After:** "Here's a cryptographic proof that no calls edge exists. Verifiable offline. Tied to commit abc123."

Same architecture serves both. The same hash that makes context cacheable makes it provable. The same root that detects staleness expires old feedback. One identity model, multiple free consequences.

## What This Costs

Content-addressing isn't free. Here are the honest tradeoffs:

**Build time is 1.4-1.7x slower than flat.** The hierarchical tree requires sorting edges into groups, building subtrees per group, then combining. A flat tree just sorts all hashes and builds one tree. At 100K edges: 27ms hierarchical vs 19ms flat. The difference is paid once per index; every subsequent operation is faster.

**First cold query on a large graph is seconds, not milliseconds.** On Grafana (249K edges), the first context retrieval takes 3.1 seconds (Random Walk with Restart + HITS scoring on 249K edges). Repeat queries against unchanged packages hit the cache at 83ns. The first query pays the full cost.

**Extraction is imperfect.** Tree-sitter parsing produces edges at 0.7 confidence. It infers "probably a call to something named X" without full type resolution. LSP enrichment upgrades these to 0.9-1.0, but takes time (gopls took 4.5 hours on Grafana's 6K Go files). You can trade accuracy for speed: skip enrichment and accept lower confidence edges.

**Integrity is tamper-evident, not tamper-proof.** The Merkle root is plain SHA-256 with no signature. An attacker with write access to the database can tamper and recompute the root. The guarantee becomes meaningful only when the root is anchored to something unforgeable: a signed git commit, an external witness log, a published hash.

**The system is n=3 validated.** Benchmarks come from three codebases: knowing itself (70K LOC Go), Spring PetClinic (Java, 47 files), and Grafana (500K LOC Go+TypeScript). The architecture is sound but hasn't been tested on 10M+ LOC monorepos, on languages with unusual package structures (Erlang, Haskell), or in adversarial environments.

**Storage grows with the snapshot chain.** Each snapshot stores edge events (added/removed edges). After 365 daily snapshots, the events table grows. Auto-GC prunes old snapshots (keeps the 10 most recent), but long-term archival needs delta compression (roadmap, not shipped).

These are real constraints. They're the difference between "this sounds theoretically nice" and "this is what it actually costs to run." Every system has costs. These are ours.

## The Bet

Git bet that content-addressing file contents would give it properties no other version control system had. It was right. Those properties (integrity, history, distributed, caching) weren't features. They were structural consequences of the identity model.

The same bet applied to code relationships gives you properties no code intelligence tool has: versioned intelligence, cryptographic proofs, self-healing memory, scoped caching, and deterministic reproducibility.

Content-addressing is not an optimization. It's an architecture. And the things it gives you for free are exactly the things that are hardest to build any other way.

---

*[knowing](https://github.com/blackwell-systems/knowing) is an open-source implementation: content-addressed code graph, hierarchical Merkle trees, 26 MCP tools, cryptographic proofs, merkleized feedback. MIT licensed. `brew install blackwell-systems/tap/knowing`*

*The hierarchical Merkle tree is available as a standalone library: [merkle-forest](https://github.com/blackwell-systems/merkle-forest). Zero dependencies.*
