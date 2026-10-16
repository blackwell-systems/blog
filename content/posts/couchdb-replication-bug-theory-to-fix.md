---
title: "How Testing a Convergence Theory Led to a Replication Bug Fix in Apache CouchDB"
date: 2026-10-16
draft: false
math: true
tags: ["couchdb", "apache-couchdb", "pouchdb", "replication", "distributed-systems", "convergence", "eventual-consistency", "revision-trees", "conflict-resolution", "validate-doc-update", "database-bugs", "formal-methods", "coq", "rocq", "model-based-testing", "preregistration", "normalization-confluence", "erlang", "open-source", "debugging", "data-integrity", "crdt", "research"]
categories: ["distributed-systems", "formal-methods", "databases"]
description: "A convergence theory, a model transcribed from CouchDB's source, a prediction that passed, one scenario it got wrong, and the upstream fix that followed."
summary: "Two CouchDB databases got the same replications in the same order. One ended with a document deleted, the other with it live, and the only difference was a validation function that accepts everything. This is the full path from a theory of convergence, to a model of CouchDB's replication, to a prediction committed before any test, to the one scenario the model got wrong, to the bug behind it and the fix that merged into CouchDB."
---

Two CouchDB databases receive the same replications from the same sources, one after another. At the end, one of them says a document is deleted. The other says it is live, with a stale revision as the winner. The only difference between the two databases is a design document whose `validate_doc_update` function accepts everything.

A validation function that rejects nothing should have no effect on what replication produces. In CouchDB 3.5.3 it did. On October 16, 2026 a fix, [apache/couchdb#6168](https://github.com/apache/couchdb/pull/6168), merged into CouchDB's main branch. A CouchDB maintainer wrote it and another approved it.

I did not go looking for this bug. I found it because a model I had built of CouchDB's replication disagreed with the real database in one scenario, and tracing that disagreement led into CouchDB's write path. This post walks through the whole path: the theory the model came from, how the model was built, the prediction it passed, the scenario it failed, and what it took to get from "my model is wrong here" to a merged fix.

{{< callout type="info" >}}
**What this post claims.** The theory did not predict this bug. It said what decides convergence and why CouchDB's history trimming matters. A model transcribed from CouchDB's source computed the outcome of every delivery order, and it passed a prediction committed before any test. A larger scenario, outside that prediction, did not match, and investigating the mismatch exposed a code path where CouchDB disagreed with itself.
{{< /callout >}}

{{< mermaid >}}
flowchart LR
    subgraph research["Research"]
        t["Theory:<br/>when do replicas<br/>that repair converge?"]
        m["Model of CouchDB<br/>transcribed from<br/>its Erlang source"]
        p["Prediction P3<br/>committed before<br/>any run"]
    end
    subgraph test["Testing"]
        pass["P3 passes:<br/>216 of 216<br/>observations match"]
        s2["Unscored scenario S2:<br/>3,009 of 5,040<br/>orders mismatch"]
        cause["Cause: two code<br/>paths for one write"]
    end
    subgraph upstream["Upstream"]
        rep["Reported with<br/>a repro"]
        conf["Confirmed<br/>by a maintainer"]
        fix["Fix merged<br/>October 16"]
    end
    t --> m --> p --> pass --> s2 --> cause --> rep --> conf --> fix

    style research fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style test fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style upstream fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

## CouchDB revisions in five minutes

If you already know CouchDB's revision trees, skip to the next section. Everything below depends on these few rules.

- **Revisions.** Every edit to a document creates a revision with an id like `3-c`: the number is the generation (how many edits deep), and the rest is a hash. In this post `1-a`, `2-b`, `3-c` and so on stand for real 32-character hashes.
- **The revision tree.** A document stores its revisions as a tree. Normally it is one path, `1-a -> 2-b -> 3-c`. Concurrent edits on different replicas create branches. A revision with no children is a **leaf**. Two or more live leaves are a **conflict**.
- **Deletion.** Deleting a document adds a new revision marked deleted, a tombstone leaf. The document counts as deleted only if every leaf is deleted.
- **The winner.** When there are several leaves, every CouchDB node picks the same winner deterministically: a live leaf beats a deleted one, then the higher generation wins, then the higher hash. So if a single old live leaf survives next to a tombstone, the document is live again, at that old revision.
- **Replicated writes.** Replication writes to the target with `_bulk_docs` and `new_edits: false`, which means "store this revision as it is, with this list of ancestors (`_revisions`)", instead of creating a new revision. The target merges that ancestor path into its tree.
- **Stemming.** Each database has a `_revs_limit`, 1,000 by default. After an update, CouchDB trims, or stems, each path to the newest `_revs_limit` revisions and forgets the older ancestors.

Stemming is where trouble starts. A stemmed tree has forgotten where it began, so if a revision later arrives that refers to the forgotten part, CouchDB can end up holding two separate roots for what was one history.

{{< mermaid >}}
flowchart LR
    subgraph full["Full history (revs_limit 1000)"]
        a1["1-a"] --> b1["2-b"] --> c1["3-c"] --> d1["4-d<br/>deleted"]
    end
    subgraph stemmed["Same document, stemmed (revs_limit 3)"]
        b2["2-b"] --> c2["3-c"] --> d2["4-d<br/>deleted"]
    end
    subgraph split["Stemmed tree after an old 1-a arrives"]
        a3["1-a<br/>live leaf"]
        b3["2-b"] --> c3["3-c"] --> d3["4-d<br/>deleted"]
    end

    style full fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style stemmed fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style split fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

In the last tree, `1-a` is a live leaf and the only other leaf is a tombstone, so by the winner rule the deleted document is back. That much is known CouchDB behavior, covered below. The bug in this post is a different way to end up with that split.

## The theory: replicas that repair themselves

The research behind this is [Normalization Confluence](https://blackwell-systems.github.io/normalization-confluence/), a theory of one question: when replicas apply the same events in different orders, and repair their state after each event, when do they still end up in the same state?

The [paper](https://doi.org/10.5281/zenodo.23311489) answers it with exact conditions. In one sentence: raw states may differ along the way, but the result after repair must agree. One of the conditions matters most here. **State descent** says the result must not depend on when repair runs. Write \(e\) for applying an event and \(N\) for repairing until the state is valid:

\[ N(e(N(s))) = N(e(s)) \]

Repairing before the event and again after it must give the same result as applying the event and repairing once. If that fails, the moment at which a replica repairs leaks into its final state. All 4,797 gated results of the theory are machine-checked in Coq with no axioms.

CouchDB maps onto this directly:

| Theory | CouchDB |
|---|---|
| An event | Delivering one revision with its ancestor path |
| Applying the event | Merging that path into the revision tree |
| Repair | Stemming the tree to `_revs_limit` |
| Convergence | Every replica ends with the same leaves, the same winner, and the same live or deleted state |

CouchDB even has a switch for when repair runs. With `stem_interactive_updates = true`, the default, it stems after every update. With it set to `false`, stemming waits until compaction. State descent says those two settings can produce different results, and that is something you can test.

## Building the model from the source

To test the theory against CouchDB I needed a model of CouchDB's replicated write path, exact enough that a disagreement with the real database would mean something. So the model was transcribed from CouchDB 3.5.3's Erlang code: `couch_key_tree.erl` for merging and stemming, `couch_db_updater.erl` for how a replicated update is applied, and the replicated-write filter in `couch_db.erl` (which comes back later). A second model follows `pouchdb-merge` from PouchDB 9.0.0, which implements the same revision-tree algorithm in JavaScript, as an independent implementation to compare against.

The theory's contribution at this stage was specific. Its at-least-once theorem, `alo_exact`, says what decides convergence when delivery can be reordered and duplicated: the steps must commute at the states that can actually be reached, and delivering something twice must change nothing. Running the model through [gsm](https://github.com/blackwell-systems/gsm), a Go library that checks these conditions on a declared system, reported where CouchDB fails them: delivering `1-a` and `2-b` after the deletion `4-d` gives different results depending on which comes first. It also showed that duplicate delivery is not the cause. And state descent explained why the stemming switch should matter.

The exact orders that bring a document back were not computed by a theorem. They came from running the models over every possible order.

## The prediction: P3

The test was written down and committed before CouchDB or PouchDB ran a single order. The file, [P3.md](https://github.com/blackwell-systems/normalization-confluence/blob/main/research/predictions/P3.md), fixes the setting, the claims, the pass and fail criteria, and a probability, and the commit that adds it is its timestamp. The framework's kernel files were frozen before it was written. If you write the prediction after you see the data, a match proves nothing.

**The setting (scenario S1).** One document with four revisions, `1-a`, `2-b`, `3-c`, `4-d`, where `4-d` is the deletion. Each revision is delivered once, with its full ancestor path, in each of the 24 possible orders, to a fresh document id in a database with `_revs_limit` 3, through `_bulk_docs` with `new_edits: false`.

**The claims**, each scored separately:

| Claim | Configuration | Computed outcome |
|---|---|---|
| 1 | CouchDB, default settings | Live with winner `1-a` on exactly the 6 orders where `1-a` arrives last; deleted on the other 18 |
| 2 | CouchDB, `stem_interactive_updates = false`, then compaction | Deleted on all 24 orders |
| 3 | PouchDB, default settings | Live on exactly the 12 orders where `1-a` arrives after `4-d`; deleted on the other 12 |

In plain words: whether a deleted document comes back depends only on the order in which the same four revisions arrive, CouchDB's stemming switch changes the outcome, and two implementations of the same algorithm disagree with each other.

I put the probability that all three claims would hold at about 0.75. The models were transcribed from current code, but transcription errors happen, and `_bulk_docs` has details a model can miss.

**The result.** Every order, in every configuration, three repetitions each in fresh databases: 216 observations, 216 matches. No order behaved nondeterministically. The leaf sets matched too, though they were not scored.

{{< callout type="warning" >}}
**The resurrection in claim 1 is known behavior.** A stray old revision bringing back a stemmed, deleted document has been discussed in CouchDB since at least 2010, when COUCHDB-988 called stemming conflicts "generally considered an acceptable tradeoff", and again in COUCHDB-1649 (2013). P3 did not report it as a bug. What P3 established was that the model reproduced CouchDB's behavior exactly, order by order, which is why the next mismatch was worth tracing instead of dismissing.
{{< /callout >}}

## The scenario the model got wrong

P3's file also allowed larger scenarios to be run and reported, unscored. One of them, S2, uses the same four-revision history in a database with `_revs_limit` 2, and delivers each revision in two copies: one with a history of length 1 and one with length 2, as if they came from different replicas that had stemmed. That is seven deliveries (`1-a` has only one possible history) and 5,040 orders.

PouchDB matched the model on all 5,040 orders. CouchDB did not: 3,009 orders disagreed on whether the document was live or which revision won.

In one example order, the first difference is small. `2-b` first arrives with history `[b]`, so the target holds `1-a` and `2-b` as two separate roots. Then `2-b` arrives again with history `[a, b]`. CouchDB merges the longer path, and the stemming step's `repair_tree` joins the two roots into one path, `a -> b`. The model ignored that second copy.

The model's behavior came from a filter in `prep_and_validate_replicated_updates` in `couch_db.erl`, transcribed faithfully. That function ignores a replicated revision that was already a leaf, or that is not a leaf after the merge. Abbreviated from CouchDB 3.5.3:

```erlang
IsOldLeaf = lists:member({Pos, RevId}, OldLeafsLU),
case dict:find({Pos, RevId}, LeafRevsFullDict) of
    {ok, {Start, Path}} when not IsOldLeaf ->
        %% [abbreviated: a new leaf; load the previous revision
        %%  and call validate_doc_update]
        ...;
    _ ->
        % this doc isn't a leaf or already exists in the tree.
        % ignore but consider it a success.
        {AccValidated, AccErrors2}
end
```

What the model missed was that CouchDB does not always call that function. In `before_docs_update`, also abbreviated, the filtering path runs only under a condition:

```erlang
ValidatePred = fun
    (#doc{id = <<?DESIGN_DOC_PREFIX, _/binary>>}) -> true;
    (#doc{atts = Atts}) -> Atts /= []
end,

case (VDFuns /= []) orelse lists:any(ValidatePred, Docs2) of
    true ->
        %% [abbreviated: run prep_and_validate_replicated_updates]
        ...;
    false ->
        {ok, DocBuckets, LocalDocs, []}
end.
```

So there are two paths for the same replicated write. If the database has a `validate_doc_update` function, or the same request contains a design document or a document with attachments, revisions go through the filter. Otherwise they go straight to the merge, unfiltered. The batch case was tested too: putting a design document in the same `_bulk_docs` request sends a database with no validation function down the filtered path.

The model had transcribed the filtered path as if it were the only one. That was a modeling error, and correcting it showed something about CouchDB:

- A corrected model, which skips the filter unless the database validates, matched a plain CouchDB database on all 5,040 orders.
- The original model, with the filter always on, matched a CouchDB database with an accept-everything `validate_doc_update` on all 5,040 orders.

Each model described one of the two databases exactly. The same revisions, delivered in the same order, ended live or deleted depending only on whether the database had a validation function, even one that does nothing. Over the 5,040 orders the live-or-deleted outcome differed on 1,460.

{{< mermaid >}}
sequenceDiagram
    participant R as Replicated write<br/>(2-b with history [a, b])
    participant P as before_docs_update
    participant F as prep_and_validate_<br/>replicated_updates
    participant U as Updater (merge, stem, repair_tree)

    Note over R,U: The target already holds 1-a and 2-b as two separate roots
    alt database has no validate_doc_update
        R->>P: write
        P->>U: revision path, unfiltered
        U-->>R: roots joined into a -> b
    else database has validate_doc_update (even accept-all)
        R->>P: write
        P->>F: filter first
        F-->>R: 2-b was already a leaf: dropped, reported as success
        Note over F: validate_doc_update is never called
    end
{{< /mermaid >}}

The model was wrong about which path a plain database takes. Reading the code to find out why is what turned up the second path, and the fact that a validation function's presence was enough to choose between them.

## Can real replication reach it?

`_bulk_docs` with `new_edits: false` is how the replicator writes, but writing those requests by hand is not the same as replication. If the real replicator never delivers a revision that a target already holds, the filter has nothing to drop and the behavior is a curiosity. So the next step was to reproduce it with ordinary edits and one-shot `POST /_replicate` runs, with nothing written by hand ([the replicator study](https://github.com/blackwell-systems/normalization-confluence/blob/main/research/couchdb-replicator/README.md)).

The way in turned out to be an optimization in the replicator's worker. Before fetching revisions, `couch_replicator_worker:find_missing` normally asks the target which ones it lacks, through `_revs_diff`. It also keeps a moving average of the fraction of checked revisions that turned out to be missing (decay 0.4). When that average passes 0.95, later batches skip `_revs_diff` and treat every revision as missing, until 37 seconds have passed since the last check. After \(k\) consecutive batches in which everything was missing, the average is \(1 - 0.6^k\): 0.922 after five, 0.953 after six. From the seventh batch on, a revision the target already holds is fetched and written again, with the source's full history.

That is the delivery S2 used: the same revision, first with a short history, later with a long one. The minimal scenario uses replicas that are all databases on one node. A, C and the two targets have `_revs_limit` 1000; B has 1 and D has 2. C, B and D replicate only document `X`. T1 has no validation function; T2 has one that accepts everything.

| Step | Action | Effect |
|---|---|---|
| 1 | A: create `X` (`1-a`); replicate A to C | C holds `1-a` |
| 2 | A: write 6 unrelated documents | they come before `X`'s next change in A's changes feed |
| 3 | A: edit `X` to `2-b`; replicate A to B | B keeps `2-b` with history `[b]` |
| 4 | T1 and T2 replicate from C, then from B | both hold two roots, `1-a` and `2-b` |
| 5 | T1 and T2 replicate from A with one worker and batch size 1 | each unrelated document is its own all-missing batch, so `X`'s batch skips `_revs_diff` and `2-b` is re-sent with history `[a, b]`. T1 joins the roots; T2 drops the write |
| 6 | A: delete `X` (`3-d`); replicate A to D; T1 and T2 replicate from D | D sends the deletion with history `[b, d]` |

| Target | Final state |
|---|---|
| T1, no `validate_doc_update` | **deleted** |
| T2, accept-all `validate_doc_update` | **live, winner `1-a`** |

With five unrelated documents instead of six, the moving average stays at 0.922, `_revs_diff` runs for `X`, and both targets end the same. Default replication settings (four workers, batches of 500) reach the same split when about 20,000 documents the target lacks precede `X` in the source's changes feed. That is roughly what an initial replication of a large database into a partly populated target looks like.

## Reporting it

I filed the report on October 11, 2026 as [apache/couchdb#6162](https://github.com/apache/couchdb/issues/6162), with a curl and jq script that reproduces the scenario above. The next day Robert Newson, a CouchDB maintainer, confirmed it as a bug for a validation function that rejects nothing. He attributed it to the `_revs_limit` of 1 and 2 in my reproduction, which he said "breaks quite a lot of things on our side, since various state comparisons vacuously fail (in this case the `oldDoc` parameter when invoking validate_doc_update)", and suggested that CouchDB arguably should not allow limits that low.

That was a reasonable hypothesis, and it changed what the issue needed. If the bug only existed at limits of 1 and 2, the fix could be a minimum limit. So the follow-up work tested what the trigger actually needs, and whether `oldDoc` is involved.

### Narrowing the trigger

On a fresh CouchDB 3.5.3, through both `_bulk_docs` and the real replicator:

- **Uniform limits never diverged.** With the same `_revs_limit` on every database (1000, and also 2, 3, 10 and 100), the two targets ended the same in every run, including documents edited 1,205 times. At a uniform limit, every database keeps the same newest ancestors of a leaf, so a longer copy of a leaf never exists.
- **Mismatched limits always diverged.** With intermediate replicas at a lower limit L, the source and targets at 1000, and a history deeper than L, the target without a validation function ended deleted and the target with an accept-all one ended live on a stale revision. This held at L = 3, 10, 100 and 999. At 999 against 1000 it needs a document with 1,000 edits, and then it happened in every run.

A minimum `_revs_limit` would not close it. Any mismatch between replicas is enough.

### Where the revision goes

Next: is the validation function involved at all? On a target holding `X` as two roots, I installed a validation function that rejects every write to `X`, then re-delivered the existing leaf with its full history. The response was `201` with no error, and the tree was unchanged. A control write of a revision the target did not have was rejected with the function's own error message.

So the re-sent leaf never reached `validate_doc_update`, and `oldDoc` is not the mechanism. The result is consistent with the "ignore but consider it a success" branch quoted above. Only the function's existence matters, because it selects the filtered path.

### Why it was intermittent

Robert noticed that the original script sometimes ended with both targets live, and always diverged when the databases were created with `?q=1&n=1` (one shard per database). That matched what I found once I stopped running only single-shard databases: the script diverged in 10 of 10 runs at q=1, 18 of 20 at the default q=2, and 3 of 10 at q=8.

The likely variable was whether the replicator re-sent `X` through the `_revs_diff` skip, which needs `X` to come after enough all-missing batches. With more shards, the changes feed interleaves documents from different shards, and `X` can come too early. A controlled test at q=8 checked this by choosing the unrelated documents' ids with `GET /db/_shards/<id>`, so they landed either in `X`'s shard or in others:

| Unrelated documents placed | Runs where `X` was re-sent and the targets diverged |
|---|---|
| All in `X`'s shard | 10 of 10 |
| All in other shards | 2 of 10 |

Across all 20 runs, the re-send (visible in the replication's `docs_written`, 7 instead of 6), the joining of the two roots on the plain target, and the divergence coincided exactly.

### A repro with no replicator

The server-side part needs neither the replicator nor any particular shard layout. Four replicated writes per target reproduce it. This script models a source at `_revs_limit` 1000 and replicas at 3, and it diverged in 30 of 30 runs at the default q, at q=1 and at q=8:

```bash
COUCH=${COUCH:-http://admin:password@127.0.0.1:5984}
J='Content-Type: application/json'
A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
C=cccccccccccccccccccccccccccccccc; D=dddddddddddddddddddddddddddddddd
E=eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee

for db in t1 t2; do curl -sS -X DELETE "$COUCH/$db" >/dev/null; curl -sS -X PUT "$COUCH/$db" >/dev/null; done
curl -sS -X PUT "$COUCH/t2/_design/accept" -H "$J" \
  -d '{"validate_doc_update":"function(newDoc, oldDoc, userCtx, secObj) {}"}' >/dev/null

put() { curl -sS -X POST "$COUCH/$1/_bulk_docs" -H "$J" -d "{\"new_edits\":false,\"docs\":[$2]}" >/dev/null; }
for t in t1 t2; do
  # from a replica that synced early: rev 1
  put $t "{\"_id\":\"X\",\"_rev\":\"1-$A\",\"_revisions\":{\"start\":1,\"ids\":[\"$A\"]},\"v\":\"a\"}"
  # from a revs_limit 3 replica: rev 4 with history [2..4], so X now has two roots
  put $t "{\"_id\":\"X\",\"_rev\":\"4-$D\",\"_revisions\":{\"start\":4,\"ids\":[\"$D\",\"$C\",\"$B\"]},\"v\":\"d\"}"
  # from the full source: rev 4 again, with its full history [1..4]
  put $t "{\"_id\":\"X\",\"_rev\":\"4-$D\",\"_revisions\":{\"start\":4,\"ids\":[\"$D\",\"$C\",\"$B\",\"$A\"]},\"v\":\"d\"}"
  # from a revs_limit 3 replica: the deletion, rev 5 with history [3..5]
  put $t "{\"_id\":\"X\",\"_rev\":\"5-$E\",\"_deleted\":true,\"_revisions\":{\"start\":5,\"ids\":[\"$E\",\"$D\",\"$C\"]}}"
done

for t in t1 t2; do
  echo "$t: $(curl -sS "$COUCH/$t/X")"
  echo "$t leaves: $(curl -sS "$COUCH/$t/X?open_revs=all&revs=true" -H 'Accept: application/json' \
    | jq -c '[.[].ok | {rev: ._rev[0:3], deleted: (._deleted // false), history: (._revisions.ids | length)}]')"
done
```

On CouchDB 3.5.3:

```text
t1: {"error":"not_found","reason":"deleted"}
t1 leaves: [{"rev":"5-e","deleted":true,"history":5}]
t2: {"_id":"X","_rev":"1-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","v":"a"}
t2 leaves: [{"rev":"1-a","deleted":false,"history":1},{"rev":"5-e","deleted":true,"history":4}]
```

{{< mermaid >}}
flowchart TB
    subgraph t1["t1, no validate_doc_update"]
        direction LR
        a1["1-a"] --> b1["2-b"] --> c1["3-c"] --> d1["4-d"] --> e1["5-e<br/>deleted, wins"]
    end
    subgraph t2["t2, accept-all validate_doc_update"]
        direction LR
        a2["1-a<br/>live, wins"]
        b2["2-b"] --> c2["3-c"] --> d2["4-d"] --> e2["5-e<br/>deleted"]
    end

    style t1 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style t2 fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

On t1, the full-history copy of `4-d` joins the two roots into one path, so when the deletion arrives, `1-a` is an interior revision and the document is deleted. On t2 that copy is dropped, `1-a` stays a separate root, and once `5-e` deletes the other branch, `1-a` is the only live leaf. A live leaf beats a deleted one, so the document comes back as it was at revision 1.

## The fix

On October 14, Nick Vatamaniuc, another CouchDB maintainer, posted an even smaller reproducer (four writes with HTTPie), and the next day he opened [the fix](https://github.com/apache/couchdb/pull/6168). His description states the cause:

> Replicated revisions, which the target already has, may come in with various revision path lengths. This can easily happen if source endpoints have different revs_limits (see #6162). Previously, if the target had a VDU, updates went through `prep_and_validate_replicated_updates/5` which incorrectly dropped any revisions already in the tree as a no-op. However, those revision paths, even if the leafs were no-ops, could still patch-up or connect some existing revisions into a single revpath.

The change adds a branch before the "ignore" case in the filter. If merging the request's revision paths changed the document's tree, the revision is passed on as a revisions-only update, with its body and attachments removed, instead of being discarded:

```erlang
_ when NewRevTree =/= OldTree ->
    % We already stored this revision or it's an
    % internal node. So we don't validate. But that
    % revision may bring in a longer connecting
    % revision path that we don't already have (say
    % if we had {1,[a]} and {2,[b]} but then get
    % {2,[a,b]}). We'd want to the update to get
    % new revpath {2, [a,b]} only.
    {[revs_only(Doc) | AccValidated], AccErrors2};
```

```erlang
revs_only(#doc{meta = Meta} = Doc) ->
    Doc#doc{body = {[]}, atts = [], meta = [{revs_only, true} | Meta]}.
```

The updater changes to match. For any replicated revision that is already in the tree, it merges the path and keeps the stored body of the leaf. A revisions-only update whose revision is no longer in the tree is ignored. Validation still does not run for a revision the database already has, and the connecting history is no longer lost. The pull request adds regression tests to `couchdb_update_conflicts_tests.erl`. Robert approved it, and it merged on October 16. A smaller patch Robert had opened earlier on October 15 is still open.

{{< mermaid >}}
timeline
    title From prediction to fix (2026, US Mountain time)
    Oct 11 : P3 committed, then run (216 of 216 match)
           : S2 mismatch traced to two write paths
           : Issue filed with a replicator repro
    Oct 12 : Confirmed as a bug by a maintainer
           : Trigger narrowed to mismatched revs_limit
    Oct 13 : Shard dependence explained
           : Four-write curl repro, 30 of 30
    Oct 14 : Second maintainer reproduces it
    Oct 15 : Fix opened with regression tests
    Oct 16 : Fix approved and merged
{{< /mermaid >}}

## Who was exposed

The conditions are specific, but they are not exotic:

- **Replicas with different `_revs_limit` values.** That is what lets the same revision exist with histories of different lengths.
- **A revision re-delivered to a target that already has it, with a longer history.** Through the replicator, the `_revs_diff` skip does this during large replications. Concurrent replications into one target are another plausible route, though that was not tested.
- **The filtered write path.** The target has a `validate_doc_update` function, or the same request holds a design document or a document with attachments.

The usual effect is that a document deleted everywhere else comes back live at an old revision on some targets. In S2 the split also went the other way on a few orders. The fix is on CouchDB's main branch, so 3.5.3 still behaves as described until a release includes it.

## What the theory did and did not do

It is tempting to tell this story as "the math found a bug." That version is wrong. Here is what each part contributed.

| Part | What it contributed | What it did not do |
|---|---|---|
| The theory | Said what decides convergence (steps commuting at reachable states, idempotent delivery, repair timing), which made CouchDB's stemming the place to look | Predict this bug, or point at `before_docs_update` |
| Transcribing the model from source | Made the model exact enough that one mismatching scenario was worth tracing | Catch the second write path; the transcription missed it |
| The committed prediction | Fixed the criteria before any data, so the 216 of 216 match showed the model reproduces CouchDB order by order on S1 | Cover S2, which was explicitly unscored |
| The unscored scenario | Produced the disagreement | Explain it; that took reading the code |
| The follow-up experiments | Took the report from "it happens at `_revs_limit` 1" to "any mismatched limit, through the real replicator, dropped in this branch before validation" | Write the fix; the maintainers did |

The theory's role came earlier than any prediction about this bug. It defines convergence for systems that repair themselves, which is what made CouchDB's stemming the interesting part. Its conditions are statements about every reachable state, which is why the model enumerated every delivery order instead of sampling a few. In the model, applying a replicated revision depended only on the tree and the revision. In CouchDB it also depended on whether the database had a validation function and on what else was in the same request. A model that enumerates every order is what made that dependence show up.

For the record on predictions: the program has made three scored predictions so far. P2, about stable matching markets, passed. P3, above, passed. P4, about Couchbase Sync Gateway, failed as scored. All three are public with their outcomes in the [predictions directory](https://github.com/blackwell-systems/normalization-confluence/tree/main/research/predictions).

## What I would tell another engineer

None of this needs a theorem prover. Most of what made it work is ordinary engineering discipline, applied to a model of someone else's code.

1. **Model from the source code.** CouchDB documents `stem_interactive_updates` as a performance switch. Running it shows that it changes which documents come back. A model built from the documentation would not have had P3's second claim at all.
2. **Write the prediction down before you run it.** A committed prediction with pass and fail criteria turns "the model seems to work" into a result, and it gives a later mismatch weight.
3. **Run more than you score.** S2 was unscored, and it was the scenario that mattered. Scoring a narrow claim and reporting everything else keeps the scored result strict without throwing away data.
4. **When the model is wrong, find the line of code that explains it.** A mismatch can mean the model is wrong, the system disagrees with itself, or both. Here it was both, and only tracing the difference to `before_docs_update` could tell them apart.
5. **Test a maintainer's hypothesis instead of arguing it.** The low limits in my first reproduction were a fair concern. Measuring uniform and mismatched limits answered it, and moved the issue forward.
6. **Hand maintainers a repro they can run in a minute.** Four replicated writes that diverge in 30 of 30 runs gave both maintainers something to run before anyone had to discuss the explanation.

## Links

- The fix: [apache/couchdb#6168](https://github.com/apache/couchdb/pull/6168)
- The report and the investigation thread: [apache/couchdb#6162](https://github.com/apache/couchdb/issues/6162)
- Prediction P3, with its outcome and the S2 analysis: [P3.md](https://github.com/blackwell-systems/normalization-confluence/blob/main/research/predictions/P3.md)
- The replicator study and the follow-up runs: [research/couchdb-replicator](https://github.com/blackwell-systems/normalization-confluence/tree/main/research/couchdb-replicator)
- The theory: the [Normalization Confluence site](https://blackwell-systems.github.io/normalization-confluence/), the [engineer's guide](https://blackwell-systems.github.io/normalization-confluence/guide/), and the paper, [doi:10.5281/zenodo.23311489](https://doi.org/10.5281/zenodo.23311489)
- Earlier on this blog: [Provable Determinism for Agent State](/posts/provable-determinism-agent-state/), the same theory applied to agent state
