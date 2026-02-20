---
title: "Instrumenting Redis for Structural Leak Detection: A jemalloc Deep Dive"
date: 2026-02-20
draft: false
series: ["structural-leaks"]
seriesOrder: 3
tags: ["memory-management", "systems-programming", "debugging", "allocators", "profiling", "c", "redis", "jemalloc", "slab-allocators", "tcache", "integration", "validation", "drainability", "fragmentation", "memory-leaks", "production", "cache-based-allocators", "symmetric-instrumentation"]
categories: ["debugging", "performance", "systems"]
description: "Instrumenting Redis with drainability profiling to detect structural fragmentation in jemalloc. Journey from wrong abstraction through asymmetric accounting bug to validated measurement: 0% DSR after 50% key deletion."
summary: "Instrumented Redis 7.2 with drainability profiling to measure jemalloc slab fragmentation. Found critical asymmetric accounting bug, fixed with symmetric fastpath instrumentation. Final result: deleting 50% of keys freed 195K objects but achieved 0% drainability - genuine structural fragmentation detected and validated."
---

Traditional leak detectors can't see structural memory leaks. [Part 1](/posts/structural-memory-leaks-drainability/) proved they cause unbounded growth. [Part 2](/posts/catching-structural-leaks/) showed integration with epoch-based allocators. Now: instrumenting Redis with jemalloc to detect structural fragmentation in a production-grade cache-based allocator.

After populating Redis with 100K keys and deleting 50% in a scattered pattern, the result: **freed 195K objects but 0% of slabs became drainable**. Every slab remained pinned by scattered surviving allocations. This is structural fragmentation.

## The Investigation Target

Redis 7.2 with jemalloc - a perfect test case:

- Production-grade in-memory database with known fragmentation issues
- Uses jemalloc's slab allocator (coarse-grained reclamation boundaries)
- Thread-local caches (tcache) create complex allocation patterns
- Scattered deletion patterns should create worst-case fragmentation

The question: after deleting 50% of keys, how many slabs can be reclaimed?

## First Attempt: The Wrong Abstraction

Initial instinct: treat jemalloc extents (2MB regions) as drainprof granules.

```c
// extent.c
extent_t *extent_alloc_wrapper(...) {
    extent_t *extent = extent_alloc_impl(...);
    if (extent && g_drainprof) {
        drainprof_granule_open(g_drainprof, (uint64_t)extent);
    }
    return extent;
}

void extent_dalloc_wrapper(...) {
    if (g_drainprof) {
        drainprof_granule_close(g_drainprof, (uint64_t)extent);
    }
    extent_dalloc_impl(...);
}
```

Instrument `arena_malloc_small()` and `arena_dalloc_small()` to register individual allocations within extents.

The code compiled. It linked. It ran.

**But it was completely wrong.**

## Understanding jemalloc's Cache Architecture

jemalloc has multiple layers:

{{< mermaid >}}
flowchart TB
    subgraph app["Application Layer"]
        redis[Redis malloc/free calls]
    end

    subgraph tcache["tcache Layer<br/>(Thread-Local Cache)"]
        bins[Cache bins per size class]
    end

    subgraph arena["Arena Layer<br/>(Per-Thread Allocator)"]
        refill[Batch refill from slabs]
        flush[Batch flush to slabs]
    end

    subgraph backing["Backing Memory"]
        extents[Extents - 2MB regions]
        slabs[Slabs - per size class]
    end

    redis --> tcache
    tcache -->|Cache miss| arena
    tcache -->|Cache full| arena
    arena --> slabs
    slabs --> extents

    style app fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style tcache fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style arena fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style backing fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The problem: 99%+ of allocations go through tcache, never touching the arena path. When you instrument `arena_malloc_small()`, you only see cache refills (batches of objects), not individual allocations.

This creates an abstraction mismatch - tracking extents but missing where actual allocations happen.

## Second Attempt: Tcache Refill/Flush

Found the right layer: instrument where tcache pulls objects from slabs (`arena_cache_bin_fill_small`) and where it returns them (`tcache_bin_flush_impl`).

```c
// arena.c - tcache refill from slab
arena_slab_reg_alloc_batch(slab, bin_info, cnt, &ptrs);

// Register all objects in the batch
for (unsigned i = 0; i < cnt; i++) {
    drainprof_alloc_register(g_drainprof,
                            (uint64_t)slab,
                            (uint64_t)ptrs[i],
                            size);
}
```

Built, ran, populated 5K keys:

```
total_allocs: 45,762
total_deallocs: 0
```

Good. Now run FLUSHALL to delete everything:

```
DSR: 0.31%
```

Wait. I just deleted everything. DSR should be near 100%.

## The Asymmetric Accounting Bug

Check the numbers after FLUSHALL:

```
Before FLUSHALL:
total_allocs:    45,767
total_deallocs:  133,197    <-- 3x more deallocs than allocs!

After FLUSHALL:
total_allocs:    45,767
total_deallocs:  193,051    <-- 4x more deallocs than allocs!
```

**The instrumentation was fundamentally broken.** We were deregistering objects that were never registered.

{{< callout type="danger" >}}
**Asymmetric tracking layers create accounting bugs:**
- Allocations tracked at arena layer (tcache refill batches only)
- Deallocations tracked at je_free fastpath (every single free)

Most allocations came from tcache's pre-existing cache, never touching the arena path we instrumented. But every free went through `je_free()`. Result: ~40K objects registered, ~190K objects deregistered.
{{< /callout >}}

## The Fix: Symmetric Fastpath Instrumentation

The solution: **track at the same layer on both sides**.

jemalloc's fast paths handle 99%+ of calls:
- `imalloc_fastpath()` for malloc
- `free_fastpath()` for free

Both operate on tcache cache bins. Both see individual allocations.

### Allocation Path

```c
// jemalloc_internal_inlines_c.h - imalloc_fastpath()
ret = cache_bin_alloc_easy(bin, &tcache_success);
if (tcache_success) {
    #ifdef ENABLE_DRAINPROF
    if (g_drainprof != NULL) {
        edata_t *edata = emap_edata_lookup(tsdn, &arena_emap_global, ret);
        if (edata != NULL && edata_slab_get(edata)) {
            uint64_t granule_id = (uint64_t)edata;

            // Lazy register slab on first allocation (idempotent)
            drainprof_granule_open(g_drainprof, granule_id);

            uint64_t alloc_id = (uint64_t)ret;
            drainprof_alloc_register(g_drainprof, granule_id,
                                    alloc_id, size);
        }
    }
    #endif
    return ret;
}
```

### Deallocation Path

```c
// jemalloc.c - free_fastpath()
if (cache_bin_dalloc_easy(bin, ptr)) {
    #ifdef ENABLE_DRAINPROF
    if (g_drainprof != NULL) {
        edata_t *edata = emap_edata_lookup(tsdn, &arena_emap_global, ptr);
        if (edata != NULL && edata_slab_get(edata)) {
            uint64_t granule_id = (uint64_t)edata;
            uint64_t alloc_id = (uint64_t)ptr;
            drainprof_alloc_deregister(g_drainprof, granule_id, alloc_id);
        }
    }
    #endif
    return true;
}
```

{{< callout type="info" >}}
**Lazy slab registration pattern:**

Use `drainprof_granule_open()` on first allocation to a slab, not when the slab is created. This works for cache-based allocators because:

1. `drainprof_granule_open()` is idempotent
2. Slabs don't have explicit close events (unlike epochs)
3. We use sweep-based occupancy surveys instead
{{< /callout >}}

## Sweep-Based Occupancy for Cache Allocators

Cache-based allocators differ from epoch-based:

| Epoch Allocators | Cache Allocators |
|-----------------|------------------|
| Explicit open/close lifecycle | Slabs persist indefinitely |
| Track close events for DSR | No close events to track |
| Report DSR on granule_close() | Need periodic occupancy survey |

For jemalloc, we added `drainprof_sweep()`:

```c
void drainprof_sweep(drainprof *prof, drainprof_snapshot_t *out) {
    uint64_t drainable_count = 0;
    uint64_t pinned_count = 0;

    // Walk all open granules (slabs)
    for (each occupied slot) {
        uint32_t live_count = atomic_load(&slot.live_count);
        if (live_count == 0) {
            drainable_count++;  // Slab is empty, can be reclaimed
        } else {
            pinned_count++;     // Slab has live objects, pinned
        }
    }

    out->dsr = drainable_count / (drainable_count + pinned_count);
}
```

This provides point-in-time drainability: what percentage of slabs are fully empty right now?

## The Validated Result

After rebuilding with symmetric instrumentation and testing:

### Symmetric Accounting Validation

```
malloc_fastpath_calls:   74,567
total_allocs:           74,572    (0.007% variance)

free_fastpath_calls:    60,666
total_deallocs:         60,668    (0.003% variance)
```

With <0.01% variance, we can trust the measurement.

### Test 1: Empty Database (Redis Internals Only)

After FLUSHALL to remove all user data:

```
total_allocs:    74,572
total_deallocs:  60,668
Live objects:    13,904 (Redis internals: dicts, SDS strings, server state)

total_slabs:     45
drainable:       1 (2.22%)
pinned:          44 (97.78%)
```

Redis's ~14K internal allocations are scattered across 44 slabs at ~316 objects/slab. Only 1 slab is drainable despite having zero user data.

### Test 2: Fragmentation Pattern (100K keys, delete 50%)

**Baseline (100K keys, 1KB values):**

```
total_allocs:     503,817
total_deallocs:   100,681
Live objects:     ~403K

total_slabs:      256
drainable:        0 (0%)
pinned:           256 (100%)
```

**After deleting 50% (odd keys via scattered pattern):**

```
total_allocs:     853,809
total_deallocs:   645,322
Live objects:     ~208K

total_slabs:      256
drainable:        0 (0%)
pinned:           256 (100%)
```

**Analysis:**

- Freed 195,641 objects (48% reduction in live data)
- Reclaimed 0 slabs (0% improvement in drainability)
- DSR remained 0%

The remaining 50K keys are scattered uniformly at ~813 objects/slab across all 256 slabs. Not a single slab became fully empty.

{{< callout type="warning" >}}
**This isn't a measurement artifact - it's a real finding.**

You deleted half your data and can't reclaim a single byte from the allocator. The freed memory is gone at the application layer but unreclaimable at the system layer because scattered surviving allocations pin every slab.

Traditional fragmentation metrics show `mem_fragmentation_ratio: 2.16` (RSS stays at 183MB while used_memory drops to 84MB). But drainability profiling tells us why: 256 slabs, 0 drainable, all pinned by scattered allocations.
{{< /callout >}}

## What We Learned

### 1. Instrumentation Must Be Symmetric

Track allocations and deallocations at the same abstraction layer. Crossing layers (arena for alloc, je_free for dealloc) creates accounting bugs that invalidate the measurement.

The wrong approach:

{{< mermaid >}}
flowchart TB
    subgraph alloc["Allocation Tracking"]
        arena_refill[arena_cache_bin_fill_small<br/>Batch refills only]
    end

    subgraph dealloc["Deallocation Tracking"]
        free_fastpath[je_free fastpath<br/>Every individual free]
    end

    arena_refill -.->|Different layers| free_fastpath

    style alloc fill:#C24F54,stroke:#6b7280,color:#f0f0f0
    style dealloc fill:#C24F54,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The correct approach:

{{< mermaid >}}
flowchart TB
    subgraph symmetric["Symmetric Fastpath Tracking"]
        imalloc[imalloc_fastpath<br/>Individual malloc calls]
        free[free_fastpath<br/>Individual free calls]
    end

    imalloc <-->|Same layer| free

    style symmetric fill:#2A9F66,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### 2. Cache-Based Allocators Need Lazy Registration

Unlike epoch-based allocators with explicit open/close lifecycles, cache-based allocators keep slabs around indefinitely.

Pattern:
- Call `drainprof_granule_open()` on first allocation (idempotent)
- Use sweep-based occupancy surveys instead of close events
- Report instantaneous drainability, not lifetime statistics

### 3. Redis Has Genuine Structural Fragmentation

The 0% DSR after 50% deletion isn't a bug - it's what happens when:

- Allocations are uniformly distributed across slabs (not clustered)
- Deletions are scattered (not sequential)
- Remaining objects pin every slab

This is the pathological case drainability profiling was designed to detect.

## Try It Yourself

**Option 1: Use the instrumented fork**

```bash
git clone https://github.com/blackwell-systems/redis-drainprof
cd redis-drainprof
./build_with_drainprof.sh
./src/redis-server --port 6380 --enable-debug-command yes
```

**Option 2: Apply patches to vanilla Redis**

```bash
git clone https://github.com/redis/redis.git redis-drainprof
cd redis-drainprof && git checkout 7.2

# Apply instrumentation (requires libdrainprof built)
git am < /path/to/drainability-profiler/examples/redis/patches/0001-*.patch

./build_with_drainprof.sh
./src/redis-server --port 6380 --enable-debug-command yes
```

**Run the fragmentation test:**

```bash
# Populate 100K keys
redis-cli -p 6380 DEBUG POPULATE 100000 key 1000

# Check baseline
redis-cli -p 6380 INFO MEMORY | grep mem_drainability_ratio
# Output: mem_drainability_ratio:0.0000

# Delete 50% (odd keys)
for i in $(seq 1 2 100000); do echo "DEL key:$i"; done | \
    redis-cli -p 6380 --pipe

# Check drainability after deletion
redis-cli -p 6380 INFO MEMORY | grep mem_drainability_ratio
# Output: mem_drainability_ratio:0.0000 (still 0%!)
```

Full integration details: [github.com/blackwell-systems/drainability-profiler/examples/redis](https://github.com/blackwell-systems/drainability-profiler/tree/main/examples/redis)

## Instrumentation Details

The complete instrumentation adds:

**1. Symmetric fastpath hooks** (imalloc_fastpath + free_fastpath)

**2. Lazy slab registration** (drainprof_granule_open on first alloc)

**3. Sweep-based DSR measurement** (drainprof_sweep)

**4. Metrics exposure via INFO MEMORY:**

```bash
redis-cli INFO MEMORY | grep drainprof
```

Output:

```
mem_drainability_ratio:0.0000              # DSR percentage
mem_drainprof_total_extents:256            # Total slabs tracked
mem_drainprof_drainable_extents:0          # Slabs with 0 live objects
mem_drainprof_pinned_extents:256           # Slabs with >0 live objects
mem_drainprof_total_allocs:853809          # Total allocations
mem_drainprof_total_deallocs:645322        # Total deallocations
mem_drainprof_malloc_fastpath_calls:74567  # Malloc fastpath hits
mem_drainprof_free_fastpath_calls:60666    # Free fastpath hits
```

## Production Implications

If you run Redis in production and see high fragmentation ratios (`mem_fragmentation_ratio > 1.5`), drainability profiling can tell you:

**High DSR (>50%)** - Fragmentation is temporary, slabs will drain over time
**Low DSR (<20%)** - Structural fragmentation, slabs stay pinned indefinitely
**0% DSR** - Worst case: scattered allocations pin every slab

Remediation strategies differ:

- **Temporary fragmentation**: Wait for natural turnover, use MEMORY PURGE
- **Structural fragmentation**: Redesign allocation patterns, cluster related data, use dedicated allocators for long-lived objects

Traditional metrics can't distinguish between these. Drainability profiling tells you which problem you have.

## Conclusion

Structural memory leaks are real, measurable, and distinct from traditional leaks. Redis demonstrates the pathological case: scattered deletion patterns pin every slab, preventing memory reclamation even after freeing half your data.

The journey from wrong abstraction (extent lifecycle) through asymmetric accounting bug to symmetric fastpath instrumentation shows that measuring drainability requires understanding the allocator's architecture deeply. You can't just sprinkle instrumentation on top - you need to track allocations and deallocations at the same layer where they actually happen.

**Result: 0% DSR means 100% of slabs are pinned.** You can delete your data, but you can't get your memory back.

---

**Code:** [redis-drainprof fork](https://github.com/blackwell-systems/redis-drainprof) | [libdrainprof](https://github.com/blackwell-systems/drainability-profiler)
**Research:** [Drainability paper (Blackwell, 2026)](https://doi.org/10.5281/zenodo.18653776)
