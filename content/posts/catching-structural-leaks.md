---
title: "Catching Structural Memory Leaks: A Temporal-Slab Case Study"
date: 2026-02-16
draft: false
series: ["structural-leaks"]
seriesOrder: 2
tags: ["memory-management", "systems-programming", "debugging", "allocators", "profiling", "c", "temporal-slab", "epoch-based", "integration", "ci", "validation"]
categories: ["debugging", "performance", "systems"]
description: "Real-world case study: integrating drainability profiling into temporal-slab allocator. See DSR measurements, diagnostic mode, and exact leak location identification with sub-2ns overhead."
summary: "From theory to practice: integrating drainability profiling into temporal-slab. See validation results (DSR = 1.0 - p), diagnostic mode pinpointing slab_lib.c:1829, and step-by-step integration guide for your allocator."
---

**TL;DR:** Traditional leak detectors miss a class of bugs where memory is properly freed but allocator granules can't be reclaimed. We integrated a drainability profiler into temporal-slab (an epoch-based allocator) to detect and diagnose these "structural leaks." The profiler adds < 2ns overhead and pinpoints exact source locations causing violations.

## The Problem: When Valgrind Says You're Fine (But You're Not)

You've seen this before: RSS grows unbounded, but Valgrind reports no leaks. Every object is properly freed. ASan is silent. Yet your service's memory footprint climbs from 500MB to 2GB over a week, and you're forced to restart it every Monday morning.

This isn't a memory leak in the traditional sense - it's a **structural leak**.

### Traditional Leaks vs Structural Leaks

**Traditional leak (Valgrind catches this):**
```c
void* ptr = malloc(1024);
// Forgot to free(ptr)
```
The object is unreachable. Tools like Valgrind detect this easily.

**Structural leak (Valgrind misses this):**
```c
// Epoch-based allocator with 1000 slots per epoch
void process_request(epoch_t* epoch) {
    void* objects[1000];
    for (int i = 0; i < 1000; i++) {
        objects[i] = epoch_alloc(epoch, 128);
    }

    // Free 999 objects
    for (int i = 0; i < 999; i++) {
        epoch_free(epoch, objects[i]);
    }

    // But object[999] outlives the epoch boundary
    save_to_session(objects[999]);  // Will be freed later
}

// When epoch closes: 999/1000 freed, but entire epoch stays allocated
epoch_close(epoch);  // Can't reclaim backing memory!
```

**The problem:** The epoch can't be reclaimed because one allocation (0.1% of objects) pins the entire granule's backing memory. Even though 99.9% of objects were freed, 100% of memory is retained.

Valgrind sees all objects eventually freed and reports success. But the allocator's coarse-grained reclamation boundaries mean the memory stays allocated indefinitely.

## Real-World Manifestation

This pattern appears in production systems using:

- **Epoch-based allocators**: Request processing where one long-lived object (session handle, cached data) pins an entire temporal epoch
- **Region allocators**: Transaction processing where one leaked reference prevents arena destruction
- **Slab allocators**: Connection pooling where one stale connection pins a 64KB slab

Traditional profilers see individual objects and report "no leaks." But the allocator sees granules (epochs, regions, slabs) that can't be drained.

## The Solution: Drainability Profiling

We need to measure **drainability** at the allocator's granule boundaries:

```
DSR (Drainability Satisfaction Rate) = drainable_closes / total_closes
```

- **DSR = 1.0**: Perfect drainability - all granules reclaimed when closed
- **DSR = 0.5**: Half of granules are pinned by lingering allocations
- **DSR = 0.0**: Every granule has pinned allocations

DSR quantifies structural leak severity - a low DSR means granules aren't draining, leading to memory retention.

## Case Study: Integrating with Temporal-Slab

[Temporal-slab](https://github.com/blackwell-systems/temporal-slab) is an epoch-based allocator that groups allocations by time. Each "epoch" is a temporal granule that should be reclaimable when closed.

### Integration Architecture

We added four instrumentation points using conditional compilation:

```c
#ifdef ENABLE_DRAINPROF
#include <drainprof.h>
extern drainprof* g_profiler;
#endif

// 1. Opening a new epoch
void epoch_advance(SlabAllocator* alloc) {
    EpochId new_epoch = alloc->current_epoch;
    // ... advance logic ...

#ifdef ENABLE_DRAINPROF
    if (g_profiler) {
        drainprof_granule_open(g_profiler, new_epoch);
    }
#endif
}

// 2. Allocating within an epoch
void* alloc_obj_epoch(SlabAllocator* alloc, size_t size, EpochId epoch) {
    void* ptr = internal_alloc(alloc, size, epoch);

#ifdef ENABLE_DRAINPROF
    if (g_profiler) {
        DRAINPROF_ALLOC_REGISTER(g_profiler, epoch, (uintptr_t)ptr, size);
    }
#endif

    return ptr;
}

// 3. Freeing an allocation
void free_obj(SlabAllocator* alloc, SlabHandle handle) {
#ifdef ENABLE_DRAINPROF
    if (g_profiler) {
        drainprof_alloc_deregister(g_profiler, handle.epoch, (uintptr_t)ptr);
    }
#endif

    internal_free(alloc, handle);
}

// 4. Closing an epoch
void epoch_close(SlabAllocator* alloc, EpochId epoch) {
#ifdef ENABLE_DRAINPROF
    if (g_profiler) {
        drainprof_granule_close(g_profiler, epoch);
    }
#endif

    // ... cleanup logic ...
}
```

**Design principles:**
- **Zero overhead when disabled**: All profiler code compiled out via `#ifdef`
- **Lock-free hot path**: < 2ns per allocation (atomic increment/decrement)
- **Optional integration**: Allocator builds and runs without profiler dependency

### Validation: P-Sweep Test

We validated the profiler measures DSR correctly by running controlled workloads with known violation probabilities.

**Test setup:** 100 epochs, 1 allocation per epoch. With probability `p`, skip freeing the allocation (simulating a structural leak).

**Theoretical prediction:** DSR = 1.0 - p

**Note on statistical variance:** With 100 epochs per run, statistical variance is significant at low p. The paper's validation uses 200K requests and achieves R²≥0.998. These CI tests use small samples for speed, not precision.

**Results:**

| Violation Rate (p) | Expected DSR | Observed DSR | Status |
|--------------------|--------------|--------------|--------|
| 0.00               | 1.000        | 1.000        | ✓ PASS |
| 0.01               | 0.990        | 1.000        | ✓ PASS |
| 0.05               | 0.950        | 0.980        | ✓ PASS |
| 0.10               | 0.900        | 0.950        | ✓ PASS |
| 0.25               | 0.750        | 0.770        | ✓ PASS |
| 0.50               | 0.500        | 0.540        | ✓ PASS |
| 1.00               | 0.000        | 0.000        | ✓ PASS |

**Validation:** DSR measurements match theoretical predictions within statistical variance (< 10% error). The profiler correctly measures drainability.

## Finding the Leak: Diagnostic Mode

Production mode tells you **if** there's a problem (low DSR). Diagnostic mode tells you **where**.

When DSR drops, enable diagnostic mode to identify allocation sites:

```c
drainprof_config config = {
    .mode = DRAINPROF_DIAGNOSTIC,
    .storage = DRAINPROF_SLOT_ARRAY,
    .slot_capacity = 128,
    .max_buffered_reports = 1000
};
g_profiler = drainprof_create_with_config(&config);
```

Run the problematic workload, then ask for a summary:

```c
drainprof_diagnostic_summary* summary =
    drainprof_diagnostic_summary_compute(g_profiler);

for (uint32_t i = 0; i < summary->site_count; i++) {
    drainprof_summary_site_entry* site = &summary->sites[i];
    printf("%s:%u - pins %u epochs (%u allocs, %zu bytes)\n",
           site->site.file, site->site.line,
           site->pinning_count, site->total_allocs, site->total_bytes);
}
```

### Real Output from Validation Test

Running a p=0.25 workload (25% of allocations leak):

```
=== Diagnostic Summary ===
Allocation sites tracked: 1

Allocation sites:
  Site 0:
    Location: slab_lib.c:1829
    Total allocs: 23
    Total bytes: 2944
    Pinning count: 23
    Expected violations: 25 (observed 23, error 2)
    ✓ PASS: Pinning count matches expected violations
    ✓ All tracked allocations from this site caused pinning
```

**The verdict:** Line 1829 in `slab_lib.c` is causing structural leaks. Every allocation from that site failed to free before the epoch closed, pinning 23 epochs.

In a real scenario, you'd:
1. Navigate to `slab_lib.c:1829`
2. Understand why allocations from that site outlive the epoch
3. Refactor to ensure cleanup before epoch close
4. Re-run and verify DSR returns to 1.0

## Performance: Is This Production-Safe?

**Production mode overhead:**
- **Allocation/deallocation:** < 2ns (atomic increment/decrement)
- **Memory per open granule:** 32 bytes (slot array entry)
- **Suitable for:** Always-on production monitoring

**Diagnostic mode overhead:**
- **Allocation/deallocation:** ~25ns (per-allocation tracking + source location capture)
- **Memory:** Proportional to number of pinned epochs
- **Suitable for:** Time-bounded investigation when DSR is low

**When disabled:** Zero overhead - all profiler code is compiled out via preprocessor.

### Benchmark Results

```
Production mode (slot array, 100 concurrent epochs):
  alloc_register:   1.97 ns/op  (508 M ops/sec)
  alloc_deregister: 1.77 ns/op  (565 M ops/sec)

Diagnostic mode (with source location capture):
  alloc_register:   24.68 ns/op  (40.5 M ops/sec)
  alloc_deregister: 20.50 ns/op  (48.8 M ops/sec)
```

For context: a typical malloc is ~50-200ns. The profiler adds 1-4% overhead in production mode.

## Continuous Integration: Keeping It Validated

Both validation tests run automatically on every push via GitHub Actions:

```yaml
- name: Build temporal-slab with profiler enabled
  run: |
    cd temporal-slab/src
    make ENABLE_DRAINPROF=1 DRAINPROF_PATH=../../drainability-profiler

- name: Run p-sweep validation
  run: ./psweep_validation

- name: Run diagnostic validation
  run: ./diagnostic_validation
```

**CI Status:** ✓ All tests passing (7/7 p-sweep tests, diagnostic mode validated)

This ensures the integration stays correct as both the profiler and allocator evolve.

## How to Integrate Your Own Allocator

The temporal-slab integration demonstrates the general pattern for any coarse-grained allocator:

### 1. Identify Your Granule Boundaries

What are the reclamation units in your allocator?
- **Epoch-based:** Temporal epochs
- **Region/Arena:** Arena lifecycle
- **Slab:** Individual slabs
- **Zone:** Zone allocator zones

### 2. Add Four Instrumentation Points

```c
#ifdef ENABLE_DRAINPROF
// When granule opens (becomes active)
drainprof_granule_open(profiler, granule_id);

// When allocation happens
DRAINPROF_ALLOC_REGISTER(profiler, granule_id, alloc_id, size);

// When allocation is freed
drainprof_alloc_deregister(profiler, granule_id, alloc_id);

// When granule closes (should be reclaimable)
drainprof_granule_close(profiler, granule_id);
#endif
```

### 3. Validate with P-Sweep

Create a controlled test that leaks allocations with probability `p` and verify DSR = 1.0 - p.

### 4. Add Diagnostic Mode Testing

Run a workload with known leaks and verify the diagnostic summary identifies the correct source locations.

## When to Use This

**Good candidates for drainability profiling:**
- Epoch-based allocators (request/transaction scoped)
- Region/arena allocators (phase-based memory management)
- Slab allocators with bulk reclamation
- Any allocator with coarse-grained reclamation boundaries

**Not useful for:**
- `malloc/free` (no coarse-grained boundaries)
- Garbage collected languages (different memory model)
- Fixed-size circular buffers (no reclamation)

**Warning signs you need this:**
- RSS grows unbounded but Valgrind reports no leaks
- Service requires periodic restarts to reclaim memory
- Memory usage has "ratchet" behavior (grows but never shrinks)
- Allocator granules have widely varying object lifetimes

## Results: What We Learned

1. **Integration is minimal**: 4 instrumentation points, < 50 lines of conditional code
2. **Overhead is negligible**: < 2ns per operation, suitable for production
3. **Validation is automated**: CI ensures correctness as code evolves
4. **Diagnosis is precise**: Exact source locations, not just "you have a leak somewhere"

Most importantly: **We can now detect structural leaks that traditional tools miss.**

## Try It Yourself

**Drainability Profiler:**
https://github.com/blackwell-systems/drainability-profiler

**Temporal-Slab Integration (working example):**
https://github.com/blackwell-systems/drainability-profiler/tree/main/examples/temporal-slab

**Research Paper:**
[Drainability: When Coarse-Grained Memory Reclamation Produces Bounded Retention](https://doi.org/10.5281/zenodo.18653776)

### Quick Start

```bash
# Clone the profiler
git clone https://github.com/blackwell-systems/drainability-profiler
cd drainability-profiler
make

# See temporal-slab integration as reference
cd examples/temporal-slab
cat README.md  # Step-by-step integration guide
```

### Create Your Own Integration

The temporal-slab README provides a template for integrating any epoch-based allocator. The pattern is:

1. Add `#ifdef ENABLE_DRAINPROF` guards
2. Instrument granule open/close and alloc/free
3. Create p-sweep and diagnostic validation tests
4. Add to CI for continuous validation

## What's Next

**Planned investigations:**
- PostgreSQL's memory contexts (similar epoch-based pattern)
- Nginx pool allocator (request-scoped pools)
- Redis arena allocator (long-running server with varied lifetimes)

**Future directions:**
- Rust bindings for Rust allocators
- Prometheus exporter for production monitoring
- Hash map storage mode for sparse granule IDs

## Conclusion

Structural memory leaks are invisible to traditional tools but cause real production issues. Drainability profiling detects these leaks by measuring reclamation success at allocator boundaries.

The temporal-slab integration proves this works in practice:
- Minimal integration effort (4 calls, conditional compilation)
- Negligible overhead (< 2ns production mode)
- Precise diagnostics (exact source locations)
- CI-validated correctness

If your service has mysterious memory growth that Valgrind can't explain, drainability profiling might be the missing piece.

---

**Author:** Dayna Blackwell
**Date:** February 16, 2026
**License:** CC-BY-4.0

**Feedback welcome:** [GitHub Issues](https://github.com/blackwell-systems/drainability-profiler/issues)
