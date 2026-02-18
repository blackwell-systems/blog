---
title: "Understanding Memory Metrics: RSS, VSZ, USS, PSS, and Working Sets"
date: 2026-02-18
draft: false
tags: ["memory-management", "systems-programming", "debugging", "linux", "performance", "metrics", "profiling", "rss", "working-set", "virtual-memory", "page-cache", "kernel", "htop", "free", "docker", "containers", "memory-pressure", "oom", "heap", "allocators", "resident-memory"]
categories: ["systems", "debugging", "performance"]
description: "A comprehensive guide to memory metrics on Linux: understand RSS, virtual memory, page cache, working sets, and why your numbers don't match. Learn which metric matters for debugging memory issues."
summary: "Why does `free` show 1GB available but your app OOM'd? Why is RSS 4GB when your heap is 2GB? A complete taxonomy of memory metrics from system level (total, available, cached) to process level (RSS, PSS, USS, WSS) to allocator internals."
---

You check your system memory:

```bash
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           15Gi       8.2Gi       1.1Gi       324Mi       6.4Gi        6.8Gi
```

Then you check your application:

```bash
$ docker stats app
CONTAINER    MEM USAGE / LIMIT     MEM %
app          2.1GiB / 4GiB        52.5%
```

And the process itself:

```bash
$ cat /proc/$(pidof app)/status | grep VmRSS
VmRSS:	     2154752 kB
```

Three different tools. Three different numbers. Your allocator reports 1.8GB in use, but RSS shows 2.1GB. The system says 8.2GB used, but 6.8GB available. What does any of this mean?

This is the memory metrics confusion that every developer encounters. This post builds a complete taxonomy: from physical RAM allocation to virtual address spaces to per-process resident sets to allocator-level tracking. By the end, you'll know which metric matters for your specific debugging scenario.

{{< callout type="info" >}}
**This post assumes**: Linux (though concepts apply broadly), x86-64 architecture. We'll define foundational concepts (pages, virtual memory) as we go.
{{< /callout >}}

## Quick Cheat Sheet

Before the deep dive, here's what matters for common scenarios:

- **System low on memory?** Check `available` in `free -h` (not `free` - that's misleading)
- **Process memory growing?** Track RSS over time via `/proc/[pid]/status` or `htop`
- **Heap vs RSS gap?** Compare allocator stats to RSS - if gap grows unbounded, you have a structural leak
- **Container OOM'd?** Check cgroup memory (`docker stats` or `memory.current` in `/sys/fs/cgroup`)
- **Shared memory accounting?** Use PSS (not RSS) to fairly divide shared pages across processes
- **Performance issues?** If Working Set Size > available RAM, you're thrashing (add RAM or reduce working set)

The rest of this post explains why these metrics exist, how they relate, and when each one matters.

## Foundational Concepts

Before diving into metrics, establish the building blocks:

### Physical Memory (RAM)

Random Access Memory - the actual hardware chips on your motherboard. Data stored in RAM is lost when power is removed (volatile). Measured in gigabytes (GB). This is the finite resource all processes compete for.

When you see "16GB RAM", that's physical memory. The kernel manages which processes get which physical pages.

### Virtual Memory

An abstraction that gives each process its own private address space. On x86-64 Linux, user processes see up to 128TB of addressable memory (lower canonical range), regardless of how much physical RAM exists.

Virtual addresses are translated to physical addresses by the Memory Management Unit (MMU) using page tables maintained by the kernel.

Multiple processes can have the same virtual address (e.g., `0x7fff00000000`) pointing to different physical pages. Virtual memory provides isolation - one process cannot see another's memory.

### Page

The fundamental unit of memory management. On x86-64 Linux, the default page size is **4KB** (4,096 bytes).

Memory is not allocated byte-by-byte. The kernel allocates full pages. When you allocate 1 byte, the kernel maps at least one 4KB page into your address space.

Pages can be:
- **Mapped**: Associated with a virtual address range in a process
- **Resident**: Physically present in RAM (vs swapped to disk)
- **Shared**: Mapped into multiple processes' address spaces
- **Dirty**: Modified since being loaded from disk
- **Clean**: Unmodified, can be discarded and re-read

### Memory Mapping

The process of linking a virtual address range to physical pages or files. Created via:

- **Anonymous mapping**: Backed by RAM (or swap), not a file. Used for heap, stack.
- **File-backed mapping**: Backed by a file on disk. Used for code, shared libraries, memory-mapped files.

Example: When you load a shared library, the kernel creates a file-backed mapping. Multiple processes loading the same library share the same physical pages.

### Address Space

The range of virtual addresses available to a process. On 64-bit Linux:

- **User space**: `0x0000000000000000` to `0x00007fffffffffff` (lower 128TB)
- **Kernel space**: `0xffff800000000000` to `0xffffffffffffffff` (upper 128TB)

Each process has its own user space address range. Kernel space is shared across all processes but only accessible in kernel mode.

### Process

An executing program with:
- Private address space (virtual memory)
- Code (instructions)
- Data (global variables)
- Heap (dynamic allocations via `malloc`)
- Stack (local variables, function call frames)
- Open files, network sockets, etc.

Each process sees its own isolated memory view. The kernel manages the mapping between virtual addresses (what the process sees) and physical pages (actual RAM).

### Kernel Space vs User Space

**User space**: Where application code runs. Cannot directly access hardware or other processes' memory. Uses system calls to request kernel services.

**Kernel space**: Where the kernel runs with full hardware access. Manages physical memory, schedules processes, handles I/O.

When you call `malloc()`, your user space code eventually makes a system call (like `brk()` or `mmap()`) that crosses into kernel space to allocate pages.

---

With these foundations established, we can now explore why measuring memory is complex.

## Why Multiple Memory Metrics Exist

Memory measurement happens at different layers of the system:

1. **Hardware layer**: Physical DRAM chips and their organization
2. **Kernel layer**: Physical pages, page cache, kernel allocations
3. **Process layer**: Virtual address spaces, mapped pages, shared memory
4. **Allocator layer**: Heap structures, freed vs allocated, internal fragmentation

Each layer sees memory differently. A page might be allocated at the kernel level (included in "used"), belong to a process's virtual address space (counted in VmSize), be physically mapped (counted in RSS), but the backing memory is freed at the allocator level (not in heap usage).

Understanding which layer you're measuring is the first step to interpreting memory metrics correctly.

## System-Level Memory Taxonomy

Start with what the kernel sees: physical RAM and how it's partitioned.

{{< mermaid >}}
flowchart TB
    subgraph physical["Physical Memory (Total RAM)"]
        direction TB
        kernel[Kernel & Slab Caches]
        userspace[Userspace Pages]
        cache[Page Cache]
        buffers[Buffers]
        free[Free Pages]
    end

    subgraph accounting["System Metrics"]
        total[total: All RAM]
        used[used: kernel + userspace + cache + buffers]
        freemem[free: unallocated pages]
        available[available: free + reclaimable]
    end

    total --> physical
    used --> kernel
    used --> userspace
    used --> cache
    used --> buffers
    freemem --> free
    available --> free
    available --> cache
    available --> buffers

    style physical fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style accounting fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Total Memory

The total amount of installed physical RAM. On most systems, a small portion is reserved by firmware/BIOS and never visible to the OS.

```bash
$ free -h
              total
Mem:           15Gi    # Actually 16GB of RAM, ~1GB reserved
```

### Used Memory

All pages allocated by the kernel or mapped to userspace processes. This includes:

- Kernel code and data structures
- Slab caches (kernel object allocators)
- Anonymous pages (process heaps, stacks)
- File-backed pages (memory-mapped files, shared libraries)
- Page cache (cached file data)
- Buffer cache (filesystem metadata, block device buffers)

**The misleading part**: Page cache and buffers are included in "used" but are instantly reclaimable. Linux aggressively caches recently accessed files in RAM. This makes "used" appear high even when the system has plenty of available memory.

### Free Memory

Pages that are completely unallocated. No process has mapped them, no kernel structure uses them, they contain no cached data.

On a healthy system, "free" memory is typically small (< 5% of total). This doesn't mean the system is low on memory - it means Linux is doing its job by caching data.

{{< callout type="warning" >}}
**Don't panic over low "free" memory**. The kernel keeps only a minimal reserve of truly free pages. Everything else is put to use caching data. When processes need memory, the kernel instantly reclaims cache pages.
{{< /callout >}}

### Available Memory

This is the metric that matters for "will my application OOM?"

Available memory estimates how much RAM can be allocated to new processes without swapping. It includes:

- Free pages (completely unallocated)
- Reclaimable cache (page cache that can be dropped)
- Reclaimable slab caches (kernel allocator caches)

```bash
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           15Gi       8.2Gi       1.1Gi       324Mi       6.4Gi        6.8Gi
```

In this example:
- 8.2GB "used" sounds bad
- 1.1GB "free" sounds worse
- But 6.8GB "available" is fine - the system has plenty of memory

The math: `available ≈ free + reclaimable_cache + reclaimable_slab`

### Page Cache

File data cached in RAM. When you read a file, Linux keeps it in the page cache. Subsequent reads are served from RAM instead of disk.

The page cache is:
- **Included in "used"** - pages are allocated
- **Included in "available"** - pages can be instantly reclaimed
- **Shared across processes** - multiple processes mapping the same file share cache pages

```bash
$ cat large_file.txt > /dev/null   # Read file, populate cache
$ free -h | grep Mem
Mem:  15Gi  8.2Gi  1.1Gi  324Mi  6.4Gi  6.8Gi   # buff/cache increased
$ cat large_file.txt > /dev/null   # Second read: instant (from cache)
```

### Buffer Cache

Metadata and block buffers for filesystems. Includes:
- Directory structures
- Inode caches
- Superblock caches
- Device block buffers

Like page cache, buffers are reclaimable but counted in "used".

## Process-Level Memory Taxonomy

Each process has its own view of memory through virtual address spaces.

{{< mermaid >}}
flowchart TB
    subgraph virtual["Virtual Address Space (VmSize)"]
        direction TB
        code[Code Segment]
        data[Data Segment]
        heap[Heap]
        mmap[Memory Mapped Files]
        stack[Stack]
        unused[Unmapped Regions]
    end

    subgraph resident["Resident Set (RSS)"]
        direction TB
        anon[Anonymous Pages - Heap/Stack]
        file[File-Backed Pages - Code/Libs]
        shared[Shared Pages - Libraries]
    end

    subgraph breakdown["RSS Accounting"]
        rss_total[RSS: All Mapped Pages]
        pss[PSS: Proportional Share]
        uss[USS: Unique Pages Only]
    end

    virtual --> resident
    resident --> breakdown

    style virtual fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style resident fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style breakdown fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Virtual Memory Size (VmSize)

The total address space reserved by a process. This includes:

- Code and data segments
- Heap (grows via `brk()` or `mmap()`)
- Thread stacks
- Memory-mapped files
- Shared libraries

```bash
$ cat /proc/$(pidof app)/status | grep VmSize
VmSize:    4589312 kB    # ~4.4GB address space
```

**Important**: VmSize is an address space reservation, not physical memory usage. You can reserve terabytes of address space without using any RAM.

Example:

```c
// Reserve 10GB of address space
void *ptr = mmap(NULL, 10ULL << 30, PROT_READ|PROT_WRITE,
                 MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
// RSS hasn't increased - no physical pages allocated yet

ptr[0] = 42;  // NOW a page is allocated (4KB of RSS increase)
```

### Resident Set Size (RSS)

The amount of physical RAM currently mapped to the process's address space. This is the actual memory consumption.

```bash
$ cat /proc/$(pidof app)/status | grep VmRSS
VmRSS:     2154752 kB    # ~2.1GB physically mapped
```

RSS includes:

- **Anonymous pages**: Heap allocations, stack, not backed by files
- **File-backed pages**: Code, shared libraries, memory-mapped files
- **Shared pages**: Libraries shared with other processes (fully counted, not divided)

RSS grows when:
- You access newly allocated anonymous pages (write faults for heap/stack)
- You read or write memory-mapped files (demand paging)
- You create threads (new stack pages)
- Pages are copied for copy-on-write (forked processes)

RSS shrinks when:
- The kernel reclaims pages under memory pressure
- You call `madvise(MADV_DONTNEED)` to release pages
- You unmap memory (`munmap()`)

{{< callout type="warning" >}}
**RSS includes shared pages**: If 10 processes map `libc.so.6`, each process's RSS includes the full library size. The total RSS across processes can exceed physical RAM because shared pages are counted multiple times.
{{< /callout >}}

### Proportional Set Size (PSS)

RSS but with shared pages divided proportionally among processes.

If `libc.so.6` is 2MB and shared by 10 processes, each process's PSS includes 200KB (2MB / 10).

```bash
$ cat /proc/$(pidof app)/smaps_rollup | grep Pss
Pss:           1987424 kB    # Lower than RSS due to shared libs
```

PSS gives a more accurate picture of per-process memory usage. Sum all processes' PSS and you get a number close to actual system memory usage.

### Unique Set Size (USS)

Memory that is completely private to the process. No shared pages counted.

USS shows what would be freed if the process exited. It's the truest measure of per-process memory cost.

Calculating USS requires walking `/proc/[pid]/smaps` and summing `Private_Clean` and `Private_Dirty`:

```bash
$ grep -E 'Private_(Clean|Dirty)' /proc/$(pidof app)/smaps | \
  awk '{sum+=$2} END {print sum " kB"}'
1802348 kB    # Unique to this process
```

**USS < PSS < RSS**: USS excludes all shared pages, PSS divides shared pages, RSS counts all pages.

### Working Set Size (WSS)

The set of pages actively accessed by the process over a time window. Not directly reported by the kernel but critical for performance.

WSS represents the minimum RAM needed to avoid thrashing. If WSS > available RAM, the process will constantly page fault.

Measuring WSS is approximate. Tools estimate it via:
- Sampling page faults with perf events
- Checking referenced bits in `/proc/kpageflags` (requires root)
- Using `mincore()` to track page residency changes
- Instrumenting page table access bits (kernel support varies)

Tools like `wss` (from Brendan Gregg's perf tools) approximate WSS using these techniques:

```bash
$ wss $(pidof app) 60
Watching PID 12345 page references for 60 seconds...
Working set size: 1.2 GB
```

WSS < RSS is normal. Not all resident pages are actively used. The gap represents cold data (old allocations, rarely accessed structures).

## The Gap: Heap vs RSS

This is where confusion often occurs and where structural memory issues appear.

Your allocator (malloc/jemalloc/tcmalloc) tracks heap allocations. The kernel tracks RSS (physical pages). These numbers don't match.

{{< mermaid >}}
flowchart TB
    subgraph app["Application View"]
        malloc[malloc/free calls]
        heap[Heap: 1.8GB in use]
    end

    subgraph allocator["Allocator View"]
        arenas[Arenas/Slabs/Pools]
        metadata[Allocator Metadata]
        freed[Freed but not returned]
    end

    subgraph kernel["Kernel View"]
        pages[Mapped Pages]
        rss[RSS: 2.1GB]
    end

    malloc --> allocator
    allocator --> kernel
    heap -.Gap: 300MB.-> rss

    style app fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style allocator fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style kernel fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Why RSS > Heap

1. **Allocator overhead**: Metadata, alignment, guard pages
2. **Granularity**: Allocators work in large chunks (arenas, slabs), not individual allocations
3. **Fragmentation**: Freed memory stays mapped until coarse-grained structures drain
4. **Retained memory**: Allocators cache freed memory for reuse instead of returning to OS

Example:

```c
// Allocate 1GB spread across many small objects
for (int i = 0; i < 1000000; i++) {
    ptrs[i] = malloc(1024);
}
// Heap in use: ~1GB
// RSS: ~1GB + allocator overhead

// Free 99% of allocations
for (int i = 0; i < 990000; i++) {
    free(ptrs[i]);
}
// Heap in use: ~10MB
// RSS: Still ~1GB (fragmented slabs can't be returned)
```

This gap - memory that's freed at the allocator level but still resident at the kernel level - is where [structural memory leaks](/posts/structural-memory-leaks-drainability/) occur.

### Decision Rule: Stable vs Growing Gap

The RSS - heap gap tells you about allocator health:

**Stable gap (normal):**
```
Hour 1: Heap 1.8GB, RSS 2.1GB (gap: 300MB)
Hour 6: Heap 1.9GB, RSS 2.2GB (gap: 300MB)
Hour 24: Heap 1.8GB, RSS 2.1GB (gap: 300MB)
```

This is expected allocator overhead. Memory use is proportional to load.

**Growing gap (structural leak):**
```
Hour 1: Heap 1.8GB, RSS 2.1GB (gap: 300MB)
Hour 6: Heap 1.9GB, RSS 2.7GB (gap: 800MB)
Hour 24: Heap 1.8GB, RSS 4.2GB (gap: 2.4GB)
```

Heap usage is stable but RSS grows. The allocator cannot return freed memory because coarse-grained structures (slabs, arenas, epochs) remain partially full. This is a drainability failure.

{{< callout type="info" >}}
**Heap < RSS is expected**. Allocators use more memory than your application directly allocates. A stable gap is normal overhead. A growing gap indicates structural leaks. Tools like [libdrainprof](https://github.com/blackwell-systems/drainability-profiler) measure allocator drainability to detect this.
{{< /callout >}}

## Page Granularity

Memory is managed in pages, not bytes. On x86-64 Linux:

- **Standard pages**: 4KB
- **Huge pages**: 2MB (enabled via Transparent Huge Pages or explicit allocation)
- **Giant pages**: 1GB (rare, usually explicit)

### Why Pages Matter

**Allocation granularity**: When you `malloc(1)`, the allocator might allocate from an existing arena, but if it needs more memory from the kernel:

```c
void *ptr = mmap(NULL, 1, ...);  // Request 1 byte
// Kernel actually maps at least one 4KB page
// RSS increases by 4KB minimum
```

**Fragmentation**: Partially used pages can't be returned. One live allocation pins the entire page.

**TLB pressure**: The CPU's Translation Lookaside Buffer caches virtual-to-physical mappings. More pages = more TLB misses = slower memory access. Huge pages (2MB) reduce this pressure.

**Page faults**: First access to a mapped page triggers a page fault (soft fault if already in RAM, hard fault if needs disk I/O). RSS increases when pages become resident - on read faults for file-backed mappings, on write faults for anonymous pages or copy-on-write.

## Dirty vs Clean Pages

Pages are classified by whether they've been modified:

### Clean Pages

- Original content unchanged
- Can be discarded and re-read from backing store (file on disk)
- Examples: Read-only code, memory-mapped files that haven't been written

### Dirty Pages

- Modified since being loaded or mapped
- Must be written to swap (or dropped via `madvise()`) before reclaiming
- Examples: Written heap allocations, modified memory-mapped files, stack pages that have been used

Anonymous memory is typically dirty once written. File-backed pages become dirty when modified.

Under memory pressure, the kernel prefers to reclaim clean pages (drop immediately) over dirty pages (must write to swap first).

```bash
$ cat /proc/$(pidof app)/status | grep -E 'RssAnon|RssFile'
RssAnon:       1842176 kB    # Typically dirty (heap, stack)
RssFile:        312576 kB    # Often clean (code, libs)
```

## Anonymous vs File-Backed Memory

### Anonymous Memory

Not backed by any file. Created via:
- `malloc()` (for large allocations, uses `mmap(MAP_ANONYMOUS)`)
- Stack allocations
- `mmap()` with `MAP_ANONYMOUS` flag

When swapped out, goes to swap space (if enabled). Otherwise, cannot be reclaimed without killing the process.

### File-Backed Memory

Mapped from files on disk:
- Code segments (executables, `.so` libraries)
- Memory-mapped files (`mmap()` without `MAP_ANONYMOUS`)
- Shared libraries

When memory pressure occurs, clean file-backed pages can be discarded and re-read from disk. No swap needed.

```bash
$ cat /proc/$(pidof app)/smaps | grep -E '^[0-9a-f].*\.so|^Pss' | head -20
7f1234560000-7f1234680000 r-xp 00000000 08:01 12345  /lib/x86_64-linux-gnu/libc.so.6
Pss:                1024 kB
7f1234680000-7f1234880000 ---p 00120000 08:01 12345  /lib/x86_64-linux-gnu/libc.so.6
Pss:                   0 kB
```

## Container Memory Accounting

Docker and Kubernetes use cgroups to limit memory. But cgroup accounting differs from process RSS.

```bash
$ docker stats app
CONTAINER    MEM USAGE / LIMIT     MEM %
app          2.1GiB / 4GiB        52.5%

# Cgroup v1 (older systems)
$ cat /sys/fs/cgroup/memory/docker/<container_id>/memory.usage_in_bytes
2201010176    # ~2.1GB

# Cgroup v2 (modern systems)
$ cat /sys/fs/cgroup/docker/<container_id>/memory.current
2201010176    # ~2.1GB
```

Cgroup memory includes:
- All process RSS
- Page cache attributed to the cgroup
- Can include some kernel memory depending on cgroup version and configuration

This can exceed the sum of individual process RSS values within the container because cached file data is shared.

{{< callout type="warning" >}}
**Container limits are cgroup limits, not RSS limits**. A process with 1GB RSS in a container with 2GB page cache will show as using 3GB at the cgroup level. When the cgroup hits its limit, the OOM killer might strike even if process RSS is low.
{{< /callout >}}

## Common Debugging Scenarios

### Scenario 1: "Why does `free` show 1GB free but my app OOM'd?"

**Check**: `available`, not `free`

```bash
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           15Gi      14.2Gi       0.8Gi       324Mi       0.5Gi        0.9Gi
```

Available memory is 0.9GB. The system is actually low on memory despite 0.8GB "free" because there's very little reclaimable cache (only 0.5GB buff/cache, most likely dirty and in active use).

**Solution**: Add RAM, reduce memory usage, enable swap, or kill memory-heavy processes.

### Scenario 2: "Valgrind says no leaks, but RSS keeps growing"

**Check**: RSS trend over time, compare to heap usage

```bash
# Track RSS growth
$ while true; do
    grep VmRSS /proc/$(pidof app)/status
    sleep 60
done

# Track heap usage (if using jemalloc)
$ echo "stats.allocated" | nc localhost 12345  # Assuming jemalloc stats server
```

If RSS grows but heap usage stays flat, you have a structural leak. The allocator cannot return freed memory to the kernel because coarse-grained structures (slabs, arenas) remain partially full.

**Solution**: Profile allocator drainability with tools like [libdrainprof](https://github.com/blackwell-systems/drainability-profiler) or switch to an allocator with better granularity for your workload.

### Scenario 3: "Docker says 2GB but RSS shows 4GB"

**Check**: Sum RSS of all processes, compare to cgroup memory

```bash
$ ps aux | awk '{sum+=$6} END {print sum/1024 " MB"}'  # RSS in KiB, convert to MB
2048 MB

# Cgroup v1
$ cat /sys/fs/cgroup/memory/docker/<id>/memory.usage_in_bytes
4294967296    # 4GB

# Cgroup v2
$ cat /sys/fs/cgroup/docker/<id>/memory.current
4294967296    # 4GB
```

The gap is page cache. Processes in the container have read files, and the page cache (2GB) is attributed to the cgroup.

**Solution**: This is normal. If the container is being OOM killed despite low RSS, you may need to increase the memory limit to account for necessary cache.

### Scenario 4: "htop shows 60% memory used, system feels fine"

**Check**: buff/cache and available

```bash
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           15Gi       9.0Gi       0.8Gi       200Mi       5.2Gi        5.8Gi
```

60% "used" but 5.8GB available. Most of the "used" memory is cache (5.2GB buff/cache). The system is healthy.

**Solution**: No action needed. This is normal Linux behavior.

### Scenario 5: "Process RSS is 500MB but heap profiler shows 200MB"

**Check**: Allocator overhead, fragmentation, retained memory

```bash
# Check allocator stats (jemalloc example)
$ malloc_stats_print()
Allocated: 209715200 bytes (200 MB)
Active: 524288000 bytes (500 MB)
Mapped: 536870912 bytes (512 MB)
```

Allocated (200MB) is what the application uses. Active (500MB) includes allocator metadata and fragmentation. Mapped (512MB) matches RSS.

**Solution**: This gap is normal. If it grows unbounded, profile allocator fragmentation and consider tuning allocator parameters.

## Decision Framework: Which Metric Matters?

| Debugging Scenario | Metric to Check | What It Tells You | Action If High |
|-------------------|----------------|-------------------|----------------|
| System running low on memory | `available` (from `free -h`) | RAM that can be allocated without swapping | Add RAM, reduce workload, investigate RSS growth |
| Process memory growth over time | RSS trend | Physical memory footprint increasing | Profile heap usage, check for leaks, measure allocator drainability |
| Suspected memory leak | RSS vs heap usage | Gap between allocated and resident memory | Run Valgrind (finds object leaks), profile allocator (finds structural leaks) |
| Shared memory accounting across processes | PSS (not RSS) | Fair attribution of shared pages | Use PSS for cost accounting, RSS for process limits |
| Container being OOM killed | Cgroup memory (`memory.current` or `memory.usage_in_bytes`) | Total memory including cache | Increase container limit or reduce cache pressure |
| Performance degradation (thrashing) | WSS vs available RAM | Working set fits in RAM? | Add RAM, reduce working set, improve locality |
| Understanding allocator behavior | RSS - heap allocations | Allocator overhead and fragmentation | Tune allocator, switch allocators, reduce fragmentation |

## When Metrics Don't Tell the Full Story

You've measured everything. RSS is stable. Heap usage tracks with RSS. No leaks detected. But memory issues persist.

This is where you need to look deeper at allocator behavior:

- **Drainability**: Can the allocator return memory when objects are freed?
- **Fragmentation**: Are coarse-grained structures (slabs, arenas, epochs) partially full?
- **Retention**: Is the allocator holding freed memory for reuse instead of returning it?

Traditional tools measure allocation and deallocation events. They don't measure whether freed memory can actually be reclaimed.

This is the gap that [structural memory leaks](/posts/structural-memory-leaks-drainability/) exploit and why [drainability profiling](https://github.com/blackwell-systems/drainability-profiler) exists.

## Tools Summary

**System-level memory:**
- `free -h` - System memory breakdown (use `available`, ignore `free`)
- `vmstat 1` - Memory stats over time
- `/proc/meminfo` - Detailed kernel memory accounting

**Process-level memory:**
- `ps aux` - RSS per process (column 6, in KiB)
- `ps -o rss= -p $(pidof app)` - RSS for specific process (cleaner than ps aux)
- `top` / `htop` - Real-time RSS monitoring
- `/proc/[pid]/status` - VmSize, VmRSS, VmData, and more
- `/proc/[pid]/smaps` - Detailed per-mapping breakdown (address ranges, permissions, RSS per mapping)
- `/proc/[pid]/smaps_rollup` - Aggregated PSS, USS, dirty/clean breakdown

**Allocator profiling:**
- `jemalloc` stats - `malloc_stats_print()` for internal state
- `tcmalloc` profiler - Heap profile snapshots
- `valgrind --tool=massif` - Heap over time
- [libdrainprof](https://github.com/blackwell-systems/drainability-profiler) - Drainability satisfaction rate

**Container memory:**
- `docker stats` - Cgroup memory usage
- `/sys/fs/cgroup/memory/` (v1) or `/sys/fs/cgroup/` (v2) - Raw cgroup memory files

## Quick Reference Glossary

**RAM (Random Access Memory)**: Physical memory chips. The finite hardware resource all processes share.

**Virtual Memory**: Per-process address space abstraction. Each process sees a private, isolated address range.

**Page**: Fundamental memory unit. 4KB on x86-64 Linux (2MB for huge pages, 1GB for giant pages).

**RSS (Resident Set Size)**: Physical memory currently mapped to a process. Includes anonymous (heap/stack) and file-backed (code/libs) pages. Shared pages counted fully in each process.

**VmSize (Virtual Memory Size)**: Total address space reserved by a process. Includes mapped and unmapped regions. Can vastly exceed physical RAM.

**PSS (Proportional Set Size)**: RSS with shared pages divided proportionally. If 10 processes share a 2MB library, each process's PSS includes 200KB.

**USS (Unique Set Size)**: Memory private to a process. Excludes all shared pages. Shows what would be freed if the process exits.

**WSS (Working Set Size)**: Pages actively accessed by a process over a time window. The minimum RAM needed to avoid thrashing.

**Page Cache**: File data cached in RAM. Included in "used" but instantly reclaimable. Makes repeated file reads fast.

**Buffer Cache**: Filesystem metadata (inodes, superblocks, directory entries) cached in RAM. Also reclaimable.

**Anonymous Pages**: Memory not backed by files. Created by `malloc()`, stack allocations. Must be swapped to disk to reclaim.

**File-Backed Pages**: Memory mapped from files. Code segments, shared libraries, memory-mapped files. Can be discarded and re-read from disk.

**Dirty Pages**: Modified since loading or mapping. Must be written to swap before reclaiming. Anonymous pages are typically dirty once written.

**Clean Pages**: Unmodified. Can be discarded immediately and re-read if needed. Read-only code pages are clean.

**Page Fault**: CPU exception when accessing unmapped or swapped-out memory. Kernel resolves by mapping a physical page.

**Swap**: Disk space used to store pages when physical RAM is full. Slower than RAM (milliseconds vs nanoseconds).

**TLB (Translation Lookaside Buffer)**: CPU cache for virtual-to-physical address translations. Reduces page table lookup overhead.

**Cgroup (Control Group)**: Linux kernel feature for resource limiting. Docker/Kubernetes use cgroups to enforce memory limits.

**OOM (Out Of Memory) Killer**: Kernel subsystem that kills processes when memory is exhausted. Selects victims based on memory usage and priority.

**Slab Cache**: Kernel's object allocator. Caches frequently allocated structures (inodes, dentries) to reduce allocation overhead.

**Huge Pages**: 2MB pages (vs standard 4KB). Reduce TLB pressure for memory-intensive applications.

**Available Memory**: Estimate of RAM that can be allocated without swapping. Includes free pages and reclaimable cache.

**Drainability**: The ability of a coarse-grained allocator (slab, arena, epoch) to return memory to the OS when objects are freed. Low drainability causes structural leaks.

## Wrapping Up

Memory measurement is a layered problem. The kernel sees pages. Processes see virtual address spaces. Allocators see heap structures. Each layer has its own accounting.

The taxonomy:

**System level**: total, used, free, available, buff/cache
**Process level**: VmSize (virtual), RSS (resident), PSS (proportional), USS (unique), WSS (working set)
**Allocator level**: heap allocated, heap overhead, fragmentation, drainability

Most debugging scenarios require checking metrics at multiple layers:

- OOM? Check `available` (system) and cgroup memory (`memory.current` or `memory.usage_in_bytes`)
- Memory leak? Check RSS trend (process) and heap usage (allocator)
- Performance? Check WSS (process) vs available RAM (system)

When metrics look healthy but problems persist, you're likely dealing with allocator-level issues - fragmentation, retention, or structural leaks that traditional tools can't see.

That's when you need to measure drainability: can the allocator actually return memory when objects are freed? For that, see the next post in this series on [structural memory leaks](/posts/structural-memory-leaks-drainability/) and tools like [libdrainprof](https://github.com/blackwell-systems/drainability-profiler).

---

**Further reading:**
- Linux `/proc` filesystem documentation: `man 5 proc`
- Kernel memory management: [kernel.org/doc/html/latest/admin-guide/mm/](https://www.kernel.org/doc/html/latest/admin-guide/mm/)
- Understanding the Linux Virtual Memory Manager: [Gorman, 2007]
- [Structural Memory Leaks and Drainability](/posts/structural-memory-leaks-drainability/) (previous post in this series)
