---
title: "Why Your Service Leaks Memory When Valgrind Says It Doesn't"
date: 2026-02-16
draft: false
series: ["structural-leaks"]
seriesOrder: 1
tags: ["memory-management", "systems-programming", "debugging", "allocators", "profiling", "c"]
categories: ["debugging", "performance", "systems"]
description: "Structural memory leaks occur when individual objects are freed but coarse-grained allocators can't reclaim memory. Learn how to detect them with sub-2ns overhead using libdrainprof."
summary: "Your memory grows. Valgrind shows zero leaks. All objects are freed. What's happening? Structural leaks: when coarse-grained allocators can't drain granules despite freed objects. Here's how to find them."
---

Your service has been running for three days. Memory usage climbed from 2GB to 18GB. You suspect a leak. You run Valgrind. Zero leaks detected. You run AddressSanitizer. Clean. You add logging to every allocation and deallocation. Everything that's allocated gets freed.

So where did 16GB go?

This is the symptom of a **structural memory leak** - a class of memory bug that traditional leak detectors cannot see because they only track individual objects, not the coarse-grained containers that hold them.

{{< callout type="warning" >}}
Traditional leak detectors (Valgrind, ASan, LeakSanitizer) only find unreachable objects. They miss situations where all objects are properly freed but the allocator cannot reclaim the backing memory because one long-lived allocation pins an entire granule.
{{< /callout >}}

## What Are Structural Leaks?

Consider a slab allocator with 1,000 slots per slab. Your service allocates 1,000 objects in slab #47. Over time, 999 of those objects are freed. But one remains - a session object that won't be freed for another hour.

Valgrind sees no leak. That one object is still reachable, still in use. But the allocator can't return slab #47 to the OS. It's pinned by a single allocation. The memory backing those 999 freed slots is gone but not reclaimable.

Multiply this pattern across thousands of slabs, epochs, or arenas over days of uptime, and you get unbounded memory growth with zero reported leaks.

{{< mermaid >}}
flowchart TB
    subgraph slab["Slab #47 (1000 slots)"]
        direction TB
        slot1[Slot 1: FREED]
        slot2[Slot 2: FREED]
        slot3[Slot 3: FREED]
        dots1[...]
        slot999[Slot 999: FREED]
        slot1000[Slot 1000: SESSION LIVE]
    end

    slab --> result[Cannot reclaim slab<br/>16KB blocked by 1 object]

    style slab fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style slot1000 fill:#C24F54,stroke:#6b7280,color:#f0f0f0
    style result fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Why Coarse-Grained Allocators?

Many high-performance systems use coarse-grained memory management:

- **Epoch-based allocators:** Allocate from epoch N, advance to N+1, reclaim epoch N when safe
- **Arena allocators:** Bulk allocation per request/connection, bulk free when done
- **Slab allocators:** Pre-allocated pools of fixed-size objects
- **Region allocators:** Grouped allocations with lifetime boundaries

These allocators trade fine-grained control for performance. But they share a property: memory is reclaimed at **granule boundaries** (epochs, arenas, slabs), not per-object. If one allocation outlives the granule's intended lifetime, the entire granule is retained.

## Introducing Drainability

The property we need to measure is called **drainability** - whether a granule can be reclaimed at its natural boundary.

**Drainable granule:** All allocations freed by the time the granule closes. Memory is reclaimable.

**Pinned granule:** At least one allocation still live when the granule closes. Memory is retained despite most objects being freed.

The metric that quantifies this is the **DSR (Drainability Satisfaction Rate)**:

```
DSR = drainable_closes / total_closes
```

- **DSR = 1.0 (100%):** Perfect drainability. All granules reclaimed.
- **DSR = 0.5 (50%):** Half of granules pinned by lingering allocations.
- **DSR = 0.0 (0%):** Every granule has pinned allocations. Severe structural leak.

{{< callout type="info" >}}
**What This Measures:** DSR tells you what fraction of your coarse-grained reclamation attempts succeed. A dropping DSR means structural leaks are accumulating. Traditional leak detectors cannot measure this because they track objects, not granules.
{{< /callout >}}

## The Tool: libdrainprof

[libdrainprof](https://github.com/blackwell-systems/drainability-profiler) is a C library that instruments coarse-grained allocators to measure drainability in production with sub-2ns overhead.

### Quick Integration

Four API calls instrument your allocator:

```c
#include <drainprof.h>

// Global profiler
drainprof *prof = drainprof_create();

// When opening a granule (epoch, arena, slab)
drainprof_granule_open(prof, granule_id);

// On each allocation
drainprof_alloc_register(prof, granule_id, alloc_id, size);

// On each deallocation
drainprof_alloc_deregister(prof, granule_id, alloc_id);

// When closing a granule
int drainable = drainprof_granule_close(prof, granule_id);
// Returns: 1 if drainable, 0 if pinned

// Read DSR
drainprof_snapshot_t snap;
drainprof_snapshot(prof, &snap);
printf("DSR: %.1f%%\n", snap.dsr * 100.0);
```

### Example: Epoch-Based Allocator

```c
typedef struct {
    uint64_t current_epoch;
    void *epoch_memory[MAX_EPOCHS];
} epoch_system_t;

void epoch_advance(epoch_system_t *sys) {
    uint64_t old_epoch = sys->current_epoch;
    sys->current_epoch++;

    // Check drainability before reclaiming
    int drainable = drainprof_granule_close(g_prof, old_epoch);
    if (drainable) {
        // Safe to reclaim
        free(sys->epoch_memory[old_epoch % MAX_EPOCHS]);
    } else {
        // Pinned! Log the leak
        fprintf(stderr, "Epoch %llu pinned by live allocations\n", old_epoch);
    }

    drainprof_granule_open(g_prof, sys->current_epoch);
}

void *epoch_alloc(epoch_system_t *sys, size_t size) {
    void *ptr = internal_alloc(sys, size);
    drainprof_alloc_register(g_prof, sys->current_epoch, (uintptr_t)ptr, size);
    return ptr;
}

void epoch_free(epoch_system_t *sys, void *ptr) {
    uint64_t epoch_id = get_epoch_for_ptr(sys, ptr);
    drainprof_alloc_deregister(g_prof, epoch_id, (uintptr_t)ptr);
    internal_free(sys, ptr);
}
```

### What You Get

After running for a few hours:

```c
drainprof_snapshot_t snap;
drainprof_snapshot(prof, &snap);

printf("Total epochs closed:     %llu\n", snap.total_closes);
printf("Drainable epochs:        %llu\n", snap.drainable_closes);
printf("Pinned epochs:           %llu\n", snap.pinned_closes);
printf("DSR:                     %.1f%%\n", snap.dsr * 100.0);
printf("Peak simultaneous open:  %llu\n", snap.peak_open_granules);
```

**Output:**
```
Total epochs closed:     10000
Drainable epochs:        8500
Pinned epochs:           1500
DSR:                     85.0%
Peak simultaneous open:  32
```

**What this tells you:** 15% of epochs are pinned. If you close 100 epochs/second, that's 15 retained epochs per second. Over 24 hours: 1.3 million pinned epochs. If each epoch is 64KB, that's 83GB of retained memory despite all individual objects being properly freed.

{{< callout type="danger" >}}
**Critical Discovery:** A DSR of 85% sounds acceptable until you multiply by close rate and uptime. Even 1% pinned granules can cause unbounded growth in long-running services.
{{< /callout >}}

## Performance: Production-Ready Overhead

The library has two modes with different overhead profiles:

### Production Mode

**Lock-free atomic operations only. No per-allocation tracking.**

| Operation | Latency | Throughput |
|-----------|---------|------------|
| `alloc_register` | **1.97 ns** | 508 M/s |
| `alloc_deregister` | **1.77 ns** | 565 M/s |

**Target:** < 10ns per operation
**Result:** Exceeded by 5x

This overhead is negligible for production monitoring. A single atomic increment per allocation. No malloc, no locks, no indirection.

### Diagnostic Mode

**Enables when production monitoring shows low DSR. Captures source locations for root-cause analysis.**

| Operation | Latency | Throughput |
|-----------|---------|------------|
| `alloc_register_located` | **24.68 ns** | 40.5 M/s |
| `alloc_deregister` | **20.50 ns** | 48.8 M/s |

**Target:** < 50ns per operation
**Result:** Within budget

10x slower than production mode due to per-allocation tracking, but acceptable for investigation. You don't run diagnostic mode in production - you enable it when production metrics show a problem.

{{< mermaid >}}
flowchart LR
    subgraph prod["Production: Always On"]
        prodmon[DSR Monitoring<br/>1.97ns overhead]
        prodmetric[DSR Metric]
    end

    subgraph diag["Diagnostic: On Demand"]
        diagmode[Per-Allocation Tracking<br/>24.68ns overhead]
        diagreport[Pinning Reports<br/>Source Locations]
    end

    prodmon --> prodmetric
    prodmetric -->|DSR drops below threshold| diagmode
    diagmode --> diagreport
    diagreport -->|Fix identified| prodmon

    style prod fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style diag fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

## Diagnostic Mode: Finding the Root Cause

When production monitoring shows DSR dropping, enable diagnostic mode to identify which allocations are pinning granules.

### Enabling Diagnostic Mode

```c
drainprof_config config;
drainprof_config_default(&config);
config.mode = DRAINPROF_DIAGNOSTIC;
config.on_pinning = NULL;  // Buffer reports for analysis

drainprof *prof = drainprof_create_with_config(&config);
```

### Capturing Source Locations

Use the macro form to capture `__FILE__` and `__LINE__`:

```c
// Instead of: drainprof_alloc_register(prof, epoch_id, ptr, size);
DRAINPROF_ALLOC_REGISTER(prof, epoch_id, ptr, size);
```

### Reading Pinning Reports

When a granule closes with live allocations, a pinning report is generated:

```c
drainprof_pinning_report *reports[100];
uint32_t count = drainprof_drain_reports(prof, reports, 100);

for (uint32_t i = 0; i < count; i++) {
    drainprof_pinning_report *report = reports[i];

    printf("Epoch %llu PINNED:\n", report->granule_id);
    printf("  Total allocations: %u\n", report->total_allocs);
    printf("  Freed before close: %u\n", report->drained_allocs);
    printf("  Still live (pinning): %u\n", report->pinning_count);

    for (uint32_t j = 0; j < report->pinning_count; j++) {
        drainprof_pinning_alloc *pa = &report->pinning_allocs[j];
        printf("    [%u] %s:%u - %zu bytes\n",
               j, pa->alloc_site.file, pa->alloc_site.line, pa->size);
    }

    drainprof_pinning_report_free(report);
}
```

**Example Output:**
```
Epoch 1047 PINNED:
  Total allocations: 2
  Freed before close: 1
  Still live (pinning): 1
    [0] src/session.c:84 - 2048 bytes
```

Now you know exactly where to look: line 84 of `session.c` is allocating something that outlives the epoch boundary.

### Aggregating by Source Location

For large-scale analysis, aggregate reports by allocation site:

```c
drainprof_diagnostic_summary *summary = drainprof_diagnostic_summary_compute(prof);

printf("Pinning allocations grouped by source location:\n");
for (uint32_t i = 0; i < summary->site_count; i++) {
    drainprof_summary_site_entry *site = &summary->sites[i];
    printf("  %s:%u\n", site->site.file, site->site.line);
    printf("    Pinned %u granules\n", site->pinning_count);
    printf("    Total: %u allocations, %zu bytes\n",
           site->total_allocs, site->total_bytes);
}

drainprof_diagnostic_summary_free(summary);
```

**Example Output:**
```
Pinning allocations grouped by source location:
  src/session.c:84
    Pinned 847 epochs
    Total: 847 allocations, 1735424 bytes
  src/connection.c:156
    Pinned 213 epochs
    Total: 213 allocations, 436224 bytes
```

**Root cause identified:** Session objects allocated at `session.c:84` are outliving epoch boundaries by a large margin. This is your structural leak.

{{< callout type="success" >}}
**Production Workflow:** Run production mode always-on with <2ns overhead. When DSR drops, enable diagnostic mode temporarily. Identify the problematic allocation sites. Fix the lifetime mismatch. Return to production monitoring.
{{< /callout >}}

## Interpreting DSR in Production

The acceptable DSR depends on your workload characteristics:

### Granule Close Rate Matters

- **1 granule/second:** DSR of 0.99 means 1 pinned granule per 100 seconds. Over 24 hours: 864 pinned granules.
- **100 granules/second:** DSR of 0.99 means 1 pinned granule per second. Over 24 hours: 86,400 pinned granules.
- **10,000 granules/second:** DSR of 0.99 means 100 pinned granules per second. Over 24 hours: 8.6 million pinned granules.

**If each granule is 64KB:**
- 864 pinned granules = 55 MB (probably fine)
- 86,400 pinned granules = 5.5 GB (concerning)
- 8.6M pinned granules = 550 GB (service will OOM)

### Service Lifetime Matters

Even DSR = 0.99 accumulates over time:

- **Hourly restarts:** 1% pinned granules may never cause issues
- **Daily restarts:** 1% pinned can accumulate to GBs
- **Weekly+ uptime:** 1% pinned becomes unbounded growth

{{< callout type="warning" >}}
**Critical Threshold:** Don't focus on absolute DSR values. Track the **trend** over time. A drop from 0.98 to 0.92 indicates a newly introduced structural leak even if 0.92 seems "acceptable" in isolation.
{{< /callout >}}

## Comparison with Traditional Leak Detectors

These tools are complementary, not competing. Use both.

| Tool | Detects Unreachable Objects | Detects Structural Leaks | Production Overhead |
|------|----------------------------|--------------------------|---------------------|
| **Valgrind** | Yes | No | 20-50x slowdown |
| **AddressSanitizer** | Yes | No | 2x slowdown |
| **LeakSanitizer** | Yes | No | Minimal |
| **libdrainprof** | No | Yes | <2ns per operation |

**Why existing tools miss this:**

Valgrind, ASan, and LSan track whether allocated memory is reachable from roots (stack, globals, registers). They detect when you call `malloc()` but never `free()` the pointer.

Structural leaks are different: every object is properly freed, but the coarse-grained allocator cannot reclaim the backing memory because allocations span granule boundaries.

**Example: HTTP Server with Epoch Allocation**

```c
typedef struct {
    uint64_t request_epoch;
    void *request_buffer;
    void *session;  // Long-lived
} http_connection_t;

void handle_request(http_connection_t *conn) {
    // Allocate from current epoch
    conn->request_epoch = g_epoch_system->current_epoch;

    // Request buffer - short-lived
    conn->request_buffer = epoch_alloc(g_epoch_system, 4096);
    DRAINPROF_ALLOC_REGISTER(g_prof, conn->request_epoch,
                             (uintptr_t)conn->request_buffer, 4096);

    // Session object - may last hours
    if (!conn->session) {
        conn->session = epoch_alloc(g_epoch_system, 2048);
        DRAINPROF_ALLOC_REGISTER(g_prof, conn->request_epoch,
                                 (uintptr_t)conn->session, 2048);
    }

    // Process request...

    // Free request buffer
    epoch_free(g_epoch_system, conn->request_buffer);
    drainprof_alloc_deregister(g_prof, conn->request_epoch,
                                (uintptr_t)conn->request_buffer);
}

void session_logout(http_connection_t *conn) {
    // Free session (finally)
    epoch_free(g_epoch_system, conn->session);
    drainprof_alloc_deregister(g_prof, conn->request_epoch,
                                (uintptr_t)conn->session);
}
```

Session objects are allocated from the request's epoch but outlive that epoch by hours. When the epoch closes, it's pinned by the session object. Valgrind sees no leak since both objects are eventually freed. But the allocator can't reclaim the epoch memory even though the request buffer was freed.

libdrainprof catches this: DSR drops from 1.0 to 0.75 over the first hour of traffic. Diagnostic mode shows `session.c:156` is pinning epochs. Fix: allocate sessions from a separate long-lived arena. After the fix, DSR returns to 0.99+ and memory stabilizes.

## When to Use This

**You need libdrainprof if:**

- You use epoch-based reclamation, arena allocators, or slab pools
- Memory grows over time but Valgrind shows no leaks
- You suspect objects are outliving their intended granule boundaries
- You need production-safe monitoring with <2ns overhead
- You want to quantify structural leak severity with a single metric (DSR)

**You don't need this if:**

- You use only `malloc`/`free` (traditional leak detectors work fine)
- Your allocator reclaims memory per-object, not per-granule
- You don't have long-running services (structural leaks accumulate over time)

{{< callout type="info" >}}
**Practical Reality:** Most high-performance systems use some form of coarse-grained allocation. If you're doing epoch-based memory management, arena allocation, or slab pools, you have the potential for structural leaks. This library makes them visible.
{{< /callout >}}

## The Theory Behind It

The DSR metric and drainability concept come from formal analysis proving when coarse-grained allocators produce bounded vs unbounded retention.

**Theorem (simplified):** If allocations violate granule boundaries with probability `p`, then retained granules grow as `R(t) ≥ p·m(t)` where `m(t)` is total closed granules. The DSR metric is `1 - p`, measuring how often granules drain successfully.

**What this means:** Even small violation rates compound over time in long-running services. A 1% violation rate (`p = 0.01`) means 1% of closed granules are retained indefinitely.

The library validates this theorem: test suite runs P-sweep experiments with `p ∈ {0.0, 0.1, 0.5, 1.0}` and confirms `DSR = 1.0 - p` exactly.

![RSS over time for seven violation fractions](/images/drainability-fan-plot.png)

*RSS over time for seven violation fractions. p=0 is flat, everything else diverges linearly. Even small violation rates cause unbounded growth in long-running services.*

**For the full proof:** See the paper [*Drainability: When Coarse-Grained Memory Reclamation Produces Bounded Retention*](https://doi.org/10.5281/zenodo.18653776) (17 pages, includes formal theorems and proofs).

**For practical usage:** Just use the tool. The math is there if you want it, but the library works whether you read the paper or not.

## Summary

Structural memory leaks occur when coarse-grained allocators cannot reclaim memory at granule boundaries despite individual objects being properly freed. Traditional leak detectors cannot see this because they only track unreachable objects.

Drainability measures whether granules can be reclaimed when they close. The DSR metric quantifies this: `DSR = drainable_closes / total_closes`. When DSR drops below 1.0, you have structural leaks accumulating.

[libdrainprof](https://github.com/blackwell-systems/drainability-profiler) instruments allocators with <2ns overhead in production mode, 25ns in diagnostic mode. Integration requires four API calls. The library captures source locations and generates pinning reports showing which allocations are preventing reclamation.

Run production mode always-on to monitor DSR. When it drops, enable diagnostic mode temporarily to identify problematic allocation sites. Fix the lifetime mismatches. Return to production monitoring. The sub-2ns overhead makes always-on production monitoring viable.

For the theory: [read the paper](https://doi.org/10.5281/zenodo.18653776). For practical debugging: use the tool.

---

**Project:** https://github.com/blackwell-systems/drainability-profiler
**Paper:** https://doi.org/10.5281/zenodo.18653776
**License:** MIT
