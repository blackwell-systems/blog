---
title: "GPL & AGPL: Freedom Through Copyleft - Complete Guide to Viral Licensing"
date: 2026-01-10
draft: false
tags: ["open-source", "licensing", "gpl", "agpl", "lgpl", "copyleft", "software-licensing", "viral-licensing", "fsf", "gnu", "legal", "mit-license", "apache-license", "compliance", "intellectual-property", "oss", "github", "project-management", "software-development", "dual-licensing", "commercial-use", "derivative-works", "developer-tools", "software-law"]
categories: ["open-source", "legal"]
series: ["Open Source Licensing"]
description: "Complete guide to GPL and AGPL copyleft licenses: how viral licensing works, GPLv2 vs GPLv3 vs LGPL vs AGPL, compliance requirements, real-world case studies (Linux, WordPress, MongoDB), and when copyleft protects your project"
summary: "Why copyleft licenses 'infect' derivative works, how GPL differs from permissive licenses, and when viral licensing protects community contributions from proprietary capture"
---

The GNU General Public License (GPL) represents a fundamentally different philosophy from permissive licenses like MIT and Apache 2.0. Where MIT says "do whatever you want," GPL says "you're free to use this, but if you distribute modifications, you must share them under the same terms." This "viral" or "copyleft" mechanism has shaped major projects like Linux, Git, WordPress, and GNU tools, while also creating legal complexity that makes corporate legal departments nervous.

{{< callout type="info" >}}
**Part 3 of Open Source Licensing Series** - Read [Part 1: MIT License Guide](/blog/posts/choosing-mit-license/) for permissive licensing and [Part 2: Apache 2.0 License Guide](/blog/posts/apache-2-license-guide/) for patent protection comparison.
{{< /callout >}}

{{< callout type="warning" >}}
**Disclaimer:** This article provides general information about software licenses and is not legal advice. Consult a qualified attorney for specific legal questions about licensing. GPL compliance has legal consequences, and violations can result in lawsuits.
{{< /callout >}}

## What is Copyleft?

### The Core Philosophy: Freedom Through Obligation

Copyleft is a licensing strategy that uses copyright law to ensure software remains free (as in freedom, not price). Unlike permissive licenses that allow anyone to do anything, copyleft licenses impose a key restriction: **if you distribute modified versions, you must share the source code under the same license.**

**The fundamental trade:**
- You receive software with full source code access
- You can modify, study, and redistribute it
- But modifications must remain open source under the same terms

**Why "copyleft"?**
The term is a play on "copyright." Traditional copyright restricts what others can do with creative works. Copyleft uses copyright law in reverse: it restricts the right to restrict. You cannot take copyleft software and make it proprietary.

### Permissive vs Copyleft: The Philosophical Divide

**Permissive licenses (MIT, Apache 2.0, BSD):**

Philosophy: Maximum freedom for users. Let them do anything, including creating proprietary derivatives.

```
Your MIT Code → User modifies → User can:
  - Release as open source (any license)
  - Release as proprietary software
  - Never share modifications
```

**Copyleft licenses (GPL, AGPL):**

Philosophy: Freedom must be preserved. Derivatives must grant the same freedoms you received.

```
Your GPL Code → User modifies → User must:
  - Release modifications as GPL if distributed
  - Provide complete source code
  - Grant same rights to downstream users
```

{{< mermaid >}}
flowchart TB
    subgraph permissive["Permissive Model (MIT)"]
        mit_start[Your MIT Code] --> mit_user[User modifies]
        mit_user --> mit_choice{User's choice}
        mit_choice -->|Option 1| mit_open[Share as open source]
        mit_choice -->|Option 2| mit_closed[Keep proprietary]
    end
    
    subgraph copyleft["Copyleft Model (GPL)"]
        gpl_start[Your GPL Code] --> gpl_user[User modifies]
        gpl_user --> gpl_must[MUST share as GPL<br/>if distributed]
        gpl_must --> gpl_dist{Distributed?}
        gpl_dist -->|Yes| gpl_share[Must provide source]
        gpl_dist -->|No| gpl_private[Can keep private]
    end
    
    style permissive fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style copyleft fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Richard Stallman and the Free Software Foundation

The GPL was created by Richard Stallman and the Free Software Foundation (FSF) in 1989. Understanding the historical context explains why GPL exists and why it's designed the way it is.

**The problem GPL solved:**

In the early 1980s, Stallman worked at MIT's AI Lab using proprietary Unix systems. When companies started making Unix proprietary (requiring NDAs, restricting modifications), he experienced firsthand how closed software limits collaboration.

**His printer story (often cited):**
- MIT's lab printer would jam frequently
- The proprietary driver had bugs
- Stallman couldn't fix it because source code was unavailable
- A colleague at another university had fixed the same bug
- But the colleague couldn't share the fix due to an NDA

This experience crystallized the problem: proprietary software takes away users' freedom to fix, improve, and share.

**The Four Freedoms (FSF definition):**

Free software must grant users:

0. **Freedom to run** the program for any purpose
1. **Freedom to study** how the program works and modify it (requires source code)
2. **Freedom to redistribute** copies to help others
3. **Freedom to distribute modified versions** to benefit the community (requires source code)

**The copyleft innovation:**

Simply releasing software as public domain doesn't ensure it stays free. Anyone can take public domain code, modify it, and release the result as proprietary software (with no source code). The original freedoms are lost.

GPL uses copyright to enforce freedom: you can do anything with GPL software except make it non-free. This is copyleft's recursive protection.

### Free as in Freedom vs Free as in Beer

**"Free software" is ambiguous in English:**

- **Free as in beer**: No cost, gratis, zero dollars
- **Free as in freedom**: Liberty, rights, lack of restrictions

**GPL ensures freedom, not price:**
- You can charge money for GPL software
- You can sell support, hosting, training
- You can distribute GPL software commercially
- But recipients must receive source code and the same freedoms

**Examples:**
- **Red Hat Enterprise Linux (GPL):** Commercial product, billions in revenue, but source code available
- **WordPress themes (GPL):** Can be sold commercially, but source must be provided to buyers

The FSF clarifies: "Think free speech, not free beer."

---

## GPL Variants: A Family of Licenses

The GPL has evolved over 35 years, spawning variants for different needs. Understanding the differences is critical for choosing the right license.

### GPLv2 (1991)

**Released:** June 1991  
**Lines:** ~2,700 words  
**Famous users:** Linux kernel, Git, MySQL (historically), Busybox

**Key characteristics:**

**No explicit patent grant:**
Unlike GPLv3 and Apache 2.0, GPLv2 doesn't explicitly address patents. This creates legal ambiguity: does the license implicitly grant patent rights, or not?

**Linking ambiguity:**
GPLv2 says derivatives must be GPL, but what counts as a derivative? The license uses terms like "work based on the Program" and "linking" without precise definitions. This created decades of debate:
- Static linking: clearly creates derivative (consensus)
- Dynamic linking: debated (LGPL exists partly to address this)
- Kernel modules: ongoing controversy in Linux

**Simple copyleft:**
If you distribute GPL software (modified or not), you must provide source code. No exceptions for hardware restrictions or patents.

**Why projects stay on GPLv2:**

**Linux kernel (Linus Torvalds):**
Linus explicitly chose GPLv2 "only" (not "GPLv2 or later") and refuses to upgrade to GPLv3. Why?
- GPLv3's anti-tivoization clause restricts how hardware manufacturers can use Linux
- Linus believes GPLv3 is too restrictive for kernel adoption
- Linux's success depends on broad hardware vendor support (including embedded devices)

**Real-world example:**
```
// Linux kernel source file header
/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
```

### GPLv3 (2007)

**Released:** June 2007 (after 18 months of public consultation)  
**Lines:** ~5,600 words  
**Famous users:** Bash, GCC, GDB, GIMP, GNU Emacs, GNU Coreutils

**Key improvements over GPLv2:**

**1. Explicit patent grant (Section 11):**

Similar to Apache 2.0, GPLv3 explicitly grants patent licenses from contributors:

```
Each contributor grants you a non-exclusive, worldwide, royalty-free patent 
license under the contributor's essential patent claims, to make, use, sell, 
offer for sale, import and otherwise run, modify and propagate the contents 
of its contributor version.
```

**Why this matters:** Prevents contributors from suing users for patent infringement related to their contributions.

**Patent retaliation clause:**
If you sue someone claiming the GPL software infringes your patents, your patent license terminates (similar to Apache 2.0).

**2. Anti-tivoization clause (Section 6):**

"Tivoization" refers to TiVo's practice: they used GPL software (Linux kernel) in their DVRs but used hardware restrictions (signed bootloaders) to prevent users from running modified versions. Technically compliant with GPLv2 (they provided source), but violated the spirit (you couldn't actually use your modifications).

**GPLv3's solution:**
If you distribute GPL software in a "User Product" (consumer device), you must provide:
- Source code
- Installation information
- Any keys/signatures needed to run modified versions

**Example requirement:**
```
If you distribute a router running GPLv3 software, you must:
1. Provide complete source code
2. Provide instructions for installing modified software
3. Provide any signing keys needed for the device to accept the modification
```

**Why GPLv2 projects won't upgrade:** Hardware vendors (routers, TVs, DVRs) don't want to share signing keys. This is why Linux stayed GPLv2.

**3. Better license compatibility:**

GPLv3 explicitly allows combination with Apache 2.0 code. GPLv2 and Apache 2.0 are incompatible (Apache's additional restrictions conflict with GPLv2's "no additional restrictions" clause).

**4. International scope:**

GPLv2 was written primarily for US law. GPLv3 uses more internationally neutral language and addresses international copyright systems.

**5. DRM/Digital restrictions:**

Section 3 addresses "Technological Protection Measures" (TPMs), clarifying that circumventing DRM on GPL software doesn't violate anti-circumvention laws (like DMCA Section 1201).

**When to use GPLv3 over GPLv2:**

+ You want explicit patent protection for users
+ You oppose tivoization (want users to actually run modified versions)
+ You need Apache 2.0 compatibility
+ You're writing new software (not constrained by GPLv2 legacy)

**When to stay on GPLv2:**

+ You need maximum hardware vendor adoption
+ Your ecosystem is GPLv2 (Linux kernel modules)
+ You don't want to alienate embedded device manufacturers
+ Simpler license text

### LGPL (Lesser GPL / Library GPL)

**Current version:** LGPLv3 (2007), but LGPLv2.1 (1999) still widely used  
**Famous users:** glibc, GTK, Qt (dual-licensed), Wine, GStreamer

**The problem LGPL solves:**

Imagine you write a useful library (e.g., a JSON parser) and license it under GPL. Any application that links against your library becomes a derivative work and must be GPL. This prevents your library from being used in proprietary applications.

**For some projects, this is undesirable:**
- You want your library widely adopted (including by proprietary software)
- But you want the library itself to remain open source
- Permissive licenses (MIT) don't ensure the library stays open

**LGPL's compromise:**

Applications can link to LGPL libraries without becoming GPL themselves. But modifications to the library must remain LGPL.

```
Proprietary Application
    |
    | (dynamic linking allowed)
    |
LGPL Library (open source)
    |
    | (modifications must be LGPL)
    |
Modified LGPL Library (must be open source)
```

**Technical requirements:**

**If you use an LGPL library in your application:**

You must:
- Provide a way for users to re-link your application with modified versions of the LGPL library
- Provide source code for the LGPL library (and any modifications you made)
- Include LGPL license text

You do NOT need to:
- Open-source your application
- Provide source code for your application
- License your application under LGPL

**Static vs Dynamic Linking:**

**Dynamic linking (DLL, .so, shared library):**
- Clearly allowed by LGPL
- Your app loads the library at runtime
- Users can replace the library with modified versions

**Static linking (compiled into binary):**
- More complicated under LGPL
- You must provide object files (.o) so users can re-link with modified library versions
- Or provide complete source code for your application

**Real-world example: Qt Framework**

Qt is dual-licensed:
- **LGPL:** Free for most uses, dynamic linking allowed, static linking requires providing object files
- **Commercial:** Paid license for proprietary applications wanting static linking without LGPL obligations

**When to choose LGPL over GPL:**

+ Your project is a library meant for wide adoption
+ You want proprietary applications to use your library
+ But you want the library itself to remain open source
+ You accept that applications using your library can be proprietary

**When to choose GPL over LGPL:**

+ You want to ensure applications using your library are also open source
+ You believe the library's value comes from the ecosystem, not just the code
+ You want maximum copyleft protection

### AGPL (Affero GPL)

**Current version:** AGPLv3 (2007)  
**Famous users:** MongoDB (historically, now SSPL), Grafana (since 2021), Bitwarden server

**The problem AGPL solves:**

GPL's copyleft trigger is **distribution**. If you modify GPL software but never distribute it to others, you're not required to share your modifications.

**The SaaS loophole:**

1. Company takes GPL software
2. Modifies it heavily (adds features, improves performance)
3. Runs it on their servers as a web service
4. Sells access to the service (no distribution occurs)
5. Never shares modifications with anyone

**This is legal under GPL.** Users access the software over the network but never receive a copy. No distribution means no copyleft obligations.

**AGPL's solution:**

AGPL adds Section 13: "Remote Network Interaction" clause.

```
If you run modified AGPL software and let users interact with it over a 
network, you must provide source code to those users.
```

**The trigger is network access, not distribution.**

**Example scenario:**

**GPL scenario:**
```
Company X:
1. Takes GPL database software
2. Adds proprietary query optimization
3. Offers "Database-as-a-Service"
4. Users connect via API/web interface
5. Source code modifications kept secret (legal under GPL)
```

**AGPL scenario:**
```
Company X:
1. Takes AGPL database software
2. Adds proprietary query optimization
3. Offers "Database-as-a-Service"
4. Users connect via API/web interface
5. MUST provide source code for modifications to users
```

**Real-world example: MongoDB's AGPL Era**

**MongoDB's journey:**
- Originally AGPL (to prevent cloud providers from offering MongoDB-as-a-service without contributing)
- AWS launched DocumentDB (MongoDB-compatible API) without using MongoDB's code
- AGPL didn't prevent this (AWS didn't use MongoDB's code, just wire protocol)
- MongoDB switched to SSPL (even stronger license, not OSI-approved)

**When to choose AGPL:**

+ Your software runs primarily as a network service (SaaS, web apps, APIs)
+ You want to prevent cloud providers from offering your software without contributing
+ You want strongest possible copyleft (closing the SaaS loophole)
+ You accept this will limit adoption (many companies avoid AGPL entirely)

**When NOT to use AGPL:**

+ You want wide corporate adoption (many companies ban AGPL in their code)
+ Your software is a library or tool (not network service)
+ You want to enable SaaS businesses around your software
+ Permissive license better fits your goals

**Corporate policies on AGPL:**

Many companies (especially startups and cloud providers) have blanket policies: "No AGPL code in production." The compliance burden and network trigger create legal risk they won't accept.

### GPL Variant Comparison

| Feature | GPLv2 | GPLv3 | LGPLv3 | AGPLv3 |
|---------|-------|-------|--------|--------|
| **Released** | 1991 | 2007 | 2007 | 2007 |
| **Copyleft trigger** | Distribution | Distribution | Distribution (library only) | Distribution or network access |
| **Patent grant** | Implicit (debated) | Explicit | Explicit | Explicit |
| **Patent retaliation** | No | Yes | Yes | Yes |
| **Anti-tivoization** | No | Yes | Yes | Yes |
| **Apache 2.0 compatible** | No | Yes | Yes | Yes |
| **SaaS loophole** | Yes | Yes | Yes | No (closed) |
| **Library usage in proprietary apps** | No | No | Yes (with conditions) | No |
| **Corporate acceptance** | Medium | Lower | Medium | Very low |
| **Linking creates derivative** | Yes | Yes | No (dynamic linking allowed) | Yes |

---

## How GPL Works in Practice

Understanding GPL requires understanding what triggers obligations, what counts as a derivative work, and what "distribution" means in modern software development.

### What Triggers GPL Obligations?

**The critical distinction: modification vs distribution**

**Scenario 1: Use only (no modifications, no distribution)**

```
You download GPL software → You run it internally
```

**GPL obligations:** None. You can use GPL software for any purpose without restrictions.

**Example:** Your company uses GCC (GPLv3) to compile proprietary software. This is fine. Using GPL tools doesn't make your output GPL.

**Scenario 2: Modify but don't distribute**

```
You download GPL software → You modify it → You run it internally only
```

**GPL obligations:** None. Private modifications don't trigger GPL obligations.

**Example:** You modify a GPL web framework to fix bugs, run it on your company's internal servers. No one outside your organization accesses it. You don't need to share modifications.

**Caveat:** AGPL changes this. Network access triggers AGPL obligations even without distribution.

**Scenario 3: Distribute without modifications**

```
You download GPL software → You distribute unmodified copies
```

**GPL obligations:** Provide source code and GPL license text.

**Example:** You bundle GCC with your Linux distribution. You must include GCC's source code (or provide written offer to supply it).

**Scenario 4: Modify and distribute (full GPL trigger)**

```
You download GPL software → You modify it → You distribute it
```

**GPL obligations:**
- Provide complete source code (original + your modifications)
- License everything under GPL
- Include GPL license text
- Include build/installation instructions
- Grant same rights to recipients

**Example:** You create a Linux distribution with custom kernel patches. You must provide:
- Original Linux source
- Your patches
- Instructions for building the kernel
- GPL license

### What Counts as a Derivative Work?

This is GPL's most legally complex question. Courts have ruled on some scenarios, but gray areas remain.

**Clear cases: Derivative works**

**1. Modifying source code:**
You edit GPL source files directly. Clearly derivative.

```c
// Original GPL file: parser.c
void parse() {
    // original implementation
}

// Your modification
void parse() {
    // your improved implementation
}
```

**2. Static linking:**
You compile GPL code into your binary. Consensus: creates single derivative work.

```
Your Code + GPL Library → Single Binary (must be GPL)
```

**3. Copying substantial portions:**
You copy significant GPL code into your project. Clearly derivative.

**Gray areas: Disputed**

**4. Dynamic linking:**

```
Your Proprietary Application
    |
    | dlopen() / LoadLibrary()
    |
GPL Library (.so / .dll)
```

**Arguments:**
- **FSF's position:** Dynamic linking creates derivative work (must be GPL)
- **Industry practice:** Many treat dynamic linking as mere aggregation (not derivative)
- **LGPL exists because of this dispute**

**Courts haven't definitively ruled.** Conservative approach: assume dynamic linking creates derivative unless using LGPL.

**5. Kernel modules (Linux-specific controversy):**

```
Linux Kernel (GPLv2)
    |
    | insmod / modprobe
    |
Driver Module
```

**Linus Torvalds' position:**
- Kernel modules that only use published kernel APIs: not necessarily derivative
- Modules with kernel-specific code: likely derivative
- Gray area depends on technical implementation

**Some companies (NVIDIA, VMware) ship proprietary kernel modules, arguing they're not derivatives. FSF disagrees. No definitive court ruling yet.**

**6. Process boundaries (pipes, sockets, RPC):**

```
GPL Program → [pipe/socket] → Your Proprietary Program
```

**General consensus:** Separate processes communicating over standard interfaces are **not** derivative works. They are "mere aggregation."

**Example:** GPL web server serving requests from proprietary application. The two programs are separate works, not derivative.

**FSF's position:** Depends on intimacy of communication. If programs are designed to work together as single system, might be derivative despite process boundaries.

**7. Plugins and extensions:**

```
GPL Base Application
    |
    | plugin interface
    |
Your Plugin
```

**Depends on technical implementation:**
- If plugin links into application's address space: likely derivative
- If plugin uses generic, published API: less likely derivative
- If plugin was designed specifically for this GPL application: more likely derivative

**Example:** WordPress (GPL) and themes/plugins. WordPress Foundation's position: themes are derivative (must be GPL), but theme authors can dual-license (GPL for PHP, proprietary for CSS/images).

### Distribution in the Modern Era

**What counts as "distribution" has evolved:**

**Clear distribution:**
- Selling software on physical media
- Providing download links
- Shipping devices with software pre-installed
- Making source code available via Git hosting

**Modern ambiguities:**

**1. SaaS / Cloud hosting:**
Under GPL (not AGPL): running software as a service is NOT distribution. Users access functionality but don't receive copies.

**2. Container images (Docker):**
Distributing Docker images with GPL software: likely distribution (users receive copies). Must provide source code.

**3. App stores:**
Distributing via Apple App Store, Google Play: clearly distribution. Must provide source code to app recipients.

**GPL and Apple App Store controversy:**
GPLv3 Section 6 requires ability to install modified versions. Apple's App Store code signing restrictions arguably conflict with this. Some developers dual-license (GPLv2 + commercial) to avoid GPLv3 App Store issues.

**4. Internal company use across entities:**
- Single legal entity using software internally across offices: not distribution
- Providing software to subsidiaries or contractors: might be distribution (depends on legal structure)

---

## GPL Compliance: What You Must Do

If you distribute GPL software (modified or not), you have specific legal obligations. Violations can result in lawsuits, injunctions, and settlements.

### Source Code Requirements

**You must provide:**

**1. Complete and corresponding source code:**

"Complete" means:
- All source files needed to build the software
- Build scripts (Makefiles, CMake, etc.)
- Installation instructions
- Any patches or modifications you made

"Corresponding" means:
- The exact source code for the binary you distribute
- Not an older version
- Not "mostly the same" code

**2. In preferred format for modifications:**

- Source code, not obfuscated or compiled
- With comments intact
- In the format developers actually use

**3. For all GPL components:**

If you distribute a product with 50 GPL libraries, you must provide source for all 50.

### Three Ways to Provide Source Code

**GPLv3 Section 6 offers three options:**

**Option 1: Include source with binary**

Distribute source code alongside binaries (e.g., on the same DVD, in the same download).

**Pros:** Simple, immediate compliance  
**Cons:** Increases download size

**Option 2: Written offer**

Provide written offer to supply source code for at least 3 years.

**Requirements:**
- Must be valid for at least 3 years from distribution
- Must be to "any third party" (not just direct recipients)
- Must be at no more than "reasonable cost of physically performing the distribution"
- Commonly used for physical products (routers, DVRs)

**Example offer:**
```
This product contains software licensed under GPLv3. Complete source code is
available for at least three years from the date of product purchase. To obtain
source code, send request to: opensource@example.com

We will provide source code on physical media for a fee not to exceed $5 USD 
(the cost of media and shipping), or via electronic download at no charge.
```

**Option 3: Network distribution**

If you distribute binaries via network (download), provide source code via network from the same location.

**Example:**
```
Binary download: https://example.com/product/myapp-1.0.bin
Source download: https://example.com/product/myapp-1.0-src.tar.gz
```

### Build Instructions

**Not enough to provide source code**

You must provide instructions for building the software. Users should be able to reproduce your binary from the source you provide.

**Required information:**
- Compiler version and flags
- Required libraries and their versions
- Build order (if multiple components)
- Configuration options used
- Any toolchain dependencies

**Example (Makefile snippet):**
```makefile
# Build instructions for MyApp 1.0
# Requires: GCC 11.2, GNU Make 4.3, zlib 1.2.11
# Build command: make CFLAGS="-O2 -march=native"

CC = gcc
CFLAGS = -O2 -march=native
LDFLAGS = -lz

myapp: main.o utils.o
    $(CC) $(CFLAGS) -o myapp main.o utils.o $(LDFLAGS)
```

### Installation Information (GPLv3)

**GPLv3 Section 6 "Installation Information" requirement:**

If you distribute GPL software in a "User Product" (consumer device), you must provide:

- Installation instructions
- Signing keys or authorization codes needed to install modified versions
- Information about how to modify the device to accept modified software

**"User Product" defined:**
Consumer products, personal devices, things sold to general public. Does NOT include: enterprise servers, industrial equipment, government systems.

**Why this matters:**
Anti-tivoization. Users should be able to install their modified versions on the device they purchased.

**Example:**
A GPL-powered router must provide:
- Source code
- Build instructions
- How to install firmware
- Any signing keys needed for bootloader

### License and Copyright Notices

**You must:**

**1. Include complete GPL license text**

Either GPLv2 or GPLv3 full text (depending on which version).

**File:** `COPYING` or `LICENSE` in root directory (by convention).

**2. Preserve all copyright notices**

Every file's copyright headers must remain intact:

```c
/*
 * Copyright (C) 2023 Original Author
 * Copyright (C) 2024 Your Company (modifications)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License.
 */
```

**3. Include prominent notices stating modifications**

GPLv3 Section 5a requires "prominent notices" on modified files:

```c
/*
 * Modified by Your Company on 2024-01-10
 * Changes: Added caching layer, optimized database queries
 */
```

**4. Changelog or modification summary**

Document what you changed. Can be separate CHANGELOG file or in commit messages.

### Dependency Tracking

**All GPL dependencies must be accounted for:**

If your product includes:
- GPL libraries
- GPL tools (compilers, build systems)
- GPL components (parsers, drivers)

You must:
- Track all GPL components
- Provide source for each
- Ensure license compatibility

**Common tools for tracking:**
- FOSSology (license scanning)
- Black Duck / Snyk (dependency analysis)
- SPDX manifests (standardized format)

**Example SPDX snippet:**
```json
{
  "name": "MyProduct",
  "packages": [
    {
      "name": "glibc",
      "version": "2.35",
      "license": "LGPL-2.1-or-later",
      "downloadLocation": "https://gnu.org/software/libc/"
    },
    {
      "name": "busybox",
      "version": "1.35.0",
      "license": "GPL-2.0-only",
      "downloadLocation": "https://busybox.net/"
    }
  ]
}
```

### Compliance Timeline

**Best practice workflow:**

**Before distribution:**
1. Audit all dependencies (identify GPL components)
2. Collect source code for all GPL components
3. Document modifications
4. Create compliance package (source code + instructions)
5. Legal review

**During distribution:**
6. Provide source code (one of three methods)
7. Include GPL license text
8. Include copyright notices
9. Include written offer (if using that method)

**After distribution:**
10. Maintain source archives for 3+ years
11. Respond to source code requests promptly
12. Update compliance package with each release

---

## Real-World Case Studies

GPL's copyleft mechanism has shaped major projects and created landmark legal cases. Understanding these stories shows GPL's power and limitations.

### Linux Kernel: GPLv2's Greatest Success

**License:** GPLv2 (explicitly "version 2 only")  
**Lines of code:** 28+ million (as of Linux 6.x)  
**Contributors:** 20,000+ developers from 1,500+ companies  
**Used in:** Billions of devices (servers, smartphones, routers, embedded systems)

**Why GPL mattered for Linux:**

**1. Prevented proprietary forks:**

In the 1980s-90s, proprietary Unix variants fragmented the market: Sun Solaris, HP-UX, IBM AIX, SCO Unix. Each was incompatible.

GPL ensured Linux improvements would be shared:
- IBM contributes enterprise features: everyone benefits
- Red Hat optimizes performance: everyone benefits
- Google adds Android features to mainline kernel: everyone benefits

**Without GPL:** Each company might have created proprietary Linux forks. The unified ecosystem wouldn't exist.

**2. Corporate contributors trust GPL:**

Companies contribute millions of lines to Linux because:
- GPL ensures competitors can't create closed-source advantage
- Improvements benefit everyone (including the contributor)
- Legal predictability (well-tested license)

**Why Linux won't upgrade to GPLv3:**

Linus Torvalds on GPLv3 anti-tivoization:

> "I think it's insane to require people to make their private signing keys available."

Linux's success depends on embedded device manufacturers (routers, TVs, cars). GPLv3's anti-tivoization would restrict hardware vendors. Linus prioritizes adoption over ideological purity.

**The NVIDIA controversy:**

NVIDIA ships proprietary kernel modules for Linux graphics drivers. Debates:
- **FSF position:** Derivative work, must be GPL
- **NVIDIA position:** Uses only published kernel APIs, not derivative
- **No court ruling yet**

Linux kernel includes MODULE_LICENSE() macro. Proprietary modules can use "Proprietary" but face restrictions (can't use certain GPL-only kernel APIs).

### WordPress: Viral Licensing in the CMS Ecosystem

**License:** GPLv2 or later  
**Market share:** 43%+ of all websites  
**Ecosystem:** 60,000+ plugins, 10,000+ themes

**WordPress Foundation's GPL stance:**

**PHP code must be GPL:** Themes and plugins are derivative works (link against WordPress core). PHP code must be GPL.

**Assets can be separate:** CSS, JavaScript, images can be separately licensed (not compiled into WordPress). Common practice: "Split licensing"

**Example split license:**
```
Theme License:
- PHP code: GPLv2 or later (required by WordPress)
- CSS/SCSS: Proprietary
- JavaScript: Proprietary
- Images/fonts: Proprietary
```

**Commercial theme controversy:**

Many premium themes are "commercially sold GPL themes":
- PHP code is GPL (buyers can redistribute)
- Design assets are proprietary (buyers can't redistribute)
- Business model: support, updates, marketplace trust

**ThemeForest's model:**
Sells GPL themes but restricts redistribution via marketplace TOS (not license). Controversial whether this violates GPL spirit.

**What GPL means for WordPress users:**

+ Any theme/plugin modifications can be distributed
+ Can hire developers to customize GPL themes
+ Can fork themes and create own versions
+ Commercial themes must provide source

### MongoDB: From AGPL to SSPL (Beyond Open Source)

**License history:**
- 2007-2018: AGPL v3
- 2018-present: Server Side Public License (SSPL)

**Why MongoDB chose AGPL initially:**

MongoDB is a database designed for web applications. AGPL's network trigger seemed perfect:
- Companies using MongoDB must share modifications
- Prevents cloud providers from offering MongoDB-as-a-service without contributing

**The AWS problem:**

2018: AWS announced **DocumentDB** - "MongoDB-compatible database"

**What AWS did:**
- Created compatible wire protocol (talks like MongoDB)
- Didn't use MongoDB's code (wrote their own engine)
- Offered managed MongoDB-compatible service
- Competed directly with MongoDB Atlas

**AGPL didn't help:** AWS didn't use MongoDB's code, so no AGPL obligations.

**MongoDB's response: SSPL**

SSPL (Server Side Public License) adds extreme requirement:

> If you offer the software as a service, you must release the source code for your entire service infrastructure (management software, monitoring, backup systems, everything).

**Example:** AWS offering MongoDB would need to open-source their entire cloud management platform.

**Consequences:**
- SSPL rejected by OSI (not open source)
- Many companies stopped using MongoDB (license uncertainty)
- SSPL seen as "bait and switch"
- Inspired other companies to similar moves (Elastic, Redis, HashiCorp)

**Lessons:**
- AGPL closes SaaS loophole for modifications
- AGPL doesn't prevent clean-room reimplementations
- Creating stronger-than-AGPL licenses alienates community
- Cloud providers have resources to reimplement rather than comply

### GNU Coreutils: The Foundation of Unix-like Systems

**License:** GPLv3  
**Famous tools:** ls, cp, mv, cat, grep, sed, awk, etc.  
**Used in:** Every Linux distribution

**Why GPL matters for core tools:**

These tools are infrastructure. GPL ensures:
- No vendor can create proprietary versions with exclusive features
- Improvements benefit all Linux distributions
- Standards remain open (commands behave consistently)

**BusyBox lawsuits (GPLv2 enforcement):**

BusyBox (GPL command-line utilities for embedded systems) has been aggressively enforced:
- 2007-2010: Multiple lawsuits against device manufacturers
- Defendants: Consumer electronics companies using BusyBox in products without providing source
- Settlements included: source code release, compliance programs, financial penalties

**Most successful GPL enforcement cases:** BusyBox cases because:
- Clear violation (distributed without source)
- Copyright holders unified (Software Freedom Conservancy)
- Defendants often unintentionally violated (lack of compliance process)

### Red Hat Enterprise Linux: Commercial Success with GPL

**License:** Mix of GPL and other open-source licenses  
**Business model:** Free software, paid support  
**Revenue:** ~$5 billion annual revenue (before IBM acquisition)

**How Red Hat makes money with GPL:**

**The model:**
1. RHEL source code is freely available (GPL requirement)
2. Binaries require paid subscription
3. Support, updates, certification are paid services
4. Value is enterprise support, not code itself

**CentOS (the free RHEL clone):**
- Community project recompiled RHEL source code
- Offered "free RHEL" (functionally identical)
- Red Hat acquired CentOS in 2014
- 2020: Red Hat killed CentOS as RHEL clone
- Community forked: Rocky Linux and AlmaLinux

**GPL's role:**
- Ensures RHEL improvements flow to all Linux distributions
- Competitors can create RHEL clones (GPL allows this)
- Red Hat's value-add (support, certification) isn't copyable via GPL

**Controversy:** Some argue Red Hat's CentOS move violated GPL spirit (making source harder to access). Legally compliant, but controversial.

---

## GPL Business Models

Copyleft doesn't prevent commercialization. Many successful businesses use GPL as their foundation.

### Model 1: Dual Licensing (GPL + Commercial)

**Concept:** Offer software under both GPL (free) and commercial license (paid).

**How it works:**
- GPL version: Free, but copyleft applies (derivatives must be GPL)
- Commercial version: Paid, proprietary use allowed (no copyleft obligations)

**Requirements:**
- You must own all copyright (or have CLAs from contributors)
- Both versions typically have same code
- Customers choose which license fits their needs

**Real-world examples:**

**MySQL (historically, before Oracle acquisition):**
- **GPL:** Free for open-source projects
- **Commercial:** Paid for proprietary applications that can't comply with GPL
- **Revenue:** Significant (led to $1 billion Oracle acquisition)

**Qt Framework:**
- **LGPL:** Free for most uses
- **Commercial:** Paid for static linking, proprietary modifications, and enterprise features
- **Revenue:** Sustainable business for decades

**When dual licensing works:**

+ You have patented technology or unique implementation
+ Corporate customers prefer paying over GPL compliance
+ You can maintain tight control over contributions (CLA required)
+ Support and updates add value beyond code

**Challenges:**

- Enforcing CLA on all contributions
- Community resentment ("bait and switch" if you change from permissive to dual GPL later)
- Maintaining two license tracks
- Requires ownership of all copyright

### Model 2: Support and Services (Red Hat Model)

**Concept:** Software is GPL (free), revenue from support contracts.

**How it works:**
- Distribute GPL software freely
- Charge for: support, consulting, training, certification
- Value-add is expertise, not code

**Why customers pay:**
- Enterprise needs guaranteed support
- Risk mitigation (vendor backing)
- Compliance assurance
- Professional services (implementation, integration)

**Real-world examples:**

**Red Hat:**
- Free software (RHEL source available per GPL)
- Revenue from subscriptions (support + updates)
- ~$5B revenue before IBM acquisition

**Canonical (Ubuntu):**
- Free Ubuntu distribution
- Revenue from Ubuntu Pro, enterprise support, consulting

**When this model works:**

+ Software is complex (databases, operating systems, infrastructure)
+ Enterprise customers need support
+ You have expertise beyond code
+ Market values reliability over price

### Model 3: Open Core (GPL Base + Proprietary Extensions)

**Concept:** Core product is GPL, premium features are proprietary.

**How it works:**
- Basic functionality: GPL (community edition)
- Enterprise features: Proprietary license (paid)
- Clear separation between open and closed

**Real-world examples:**

**GitLab (before full open-source):**
- Community Edition: GPL
- Enterprise Edition: Proprietary features (LDAP, HA, advanced permissions)

**Grafana (mixed licensing):**
- Core: AGPL (changed from Apache 2.0 in 2021)
- Enterprise plugins: Proprietary

**Challenges with GPL open core:**

- GPL base means competitors can fork
- Community may implement enterprise features (undermining paid version)
- "Crippleware" criticism if free version too limited
- Harder to maintain separation than with permissive licenses

### Model 4: Hosting/SaaS (Managed Service)

**Concept:** Software is GPL, but hosting service is paid.

**How it works:**
- Anyone can self-host GPL software (free)
- You charge for managed hosting (convenience)
- Revenue from infrastructure, not software

**Examples:**

**WordPress.com:**
- WordPress core: GPL
- Hosted service: Paid tiers
- Revenue from hosting, not software

**Discourse:**
- Forum software: GPL
- Managed hosting: Paid service
- Revenue from convenience and support

**Why this works despite GPL:**
- Hosting requires infrastructure investment
- Managed service adds monitoring, backups, updates
- Customers pay for convenience, not license

---

## GPL Compliance Case Law

GPL has been tested in courts worldwide. Understanding precedents shows what violations look like and consequences.

### Versata v. Ameriprise (US, 2014)

**Facts:**
- Versata sold software using XimpelWare (GPL'd parser)
- Versata's software was proprietary
- Court ruled Versata violated GPL

**Ruling:**
- GPL is enforceable contract
- Versata had no license to use XimpelWare (violated GPL terms)
- Awarded $12.5 million to copyright holder

**Lesson:** Using GPL components in proprietary software without compliance is copyright infringement.

### BusyBox GPL Lawsuits (US, 2007-2010)

**Facts:**
- Multiple consumer electronics companies used BusyBox in devices
- Devices distributed without source code or GPL notices
- Software Freedom Conservancy sued on behalf of BusyBox developers

**Settlements:**
- Companies required to release source code
- Implement GPL compliance programs
- Financial penalties (amounts often confidential)

**Lesson:** Embedded device manufacturers must comply. "We didn't know" isn't a defense.

### Welte v. Sitecom (Germany, 2004)

**Facts:**
- First GPL court case in Germany
- Harald Welte (Linux kernel developer) sued Sitecom
- Sitecom distributed router with Linux but no source code

**Ruling:**
- Preliminary injunction granted
- Sitecom required to provide source code
- GPL enforceable under German law

**Lesson:** GPL is enforceable internationally.

### Artifex v. Hancom (US, 2017)

**Facts:**
- Hancom used Ghostscript (dual-licensed: AGPL + commercial)
- Hancom used AGPL version but didn't provide source
- Claimed "GPL is unenforceable"

**Ruling:**
- AGPL is enforceable
- Hancom lost license rights by violating terms
- Case settled before final judgment

**Lesson:** AGPL network obligation is legally binding.

---

## When to Choose GPL/AGPL

### Choose GPLv2 when:

+ Building operating system or kernel-level software
+ Maximum adoption from hardware vendors matters
+ You want simpler license terms (no anti-tivoization)
+ Your ecosystem is already GPLv2 (Linux kernel modules)
+ You want time-tested legal precedent

### Choose GPLv3 when:

+ You want explicit patent protection for users
+ You oppose tivoization (users should run modified versions)
+ You need Apache 2.0 compatibility
+ International scope matters
+ You're writing new software (no legacy constraints)

### Choose LGPL when:

+ Your project is a library
+ You want wide adoption (including proprietary apps)
+ But you want the library itself to stay open source
+ Dynamic linking should not create derivative works

### Choose AGPL when:

+ Your software is primarily a network service
+ You want to close the SaaS loophole
+ You want maximum copyleft (strongest protection)
+ You accept very limited corporate adoption
+ Preventing cloud provider exploitation is critical

### Choose permissive (MIT/Apache) instead when:

+ You want maximum adoption without restrictions
+ Corporate acceptance is critical
+ You don't care if someone creates proprietary fork
+ Simplicity over enforcement
+ You want to enable commercial SaaS offerings

---

## GPL vs MIT vs Apache: Final Comparison

| Feature | MIT | Apache 2.0 | GPLv2 | GPLv3 | LGPL | AGPL |
|---------|-----|------------|-------|-------|------|------|
| **Philosophy** | Permissive | Permissive + patents | Copyleft | Copyleft + patents | Weak copyleft | Network copyleft |
| **Proprietary derivatives allowed** | Yes | Yes | No | No | Yes (apps only) | No |
| **Patent grant** | No | Explicit | Implicit | Explicit | Explicit | Explicit |
| **Patent retaliation** | No | Yes | No | Yes | Yes | Yes |
| **SaaS loophole** | N/A | N/A | Yes | Yes | Yes | No (closed) |
| **Anti-tivoization** | No | No | No | Yes | Yes | Yes |
| **Copyleft trigger** | N/A | N/A | Distribution | Distribution | Distribution (lib only) | Distribution or network |
| **Source code disclosure required** | No | No | Yes (if distributed) | Yes (if distributed) | Yes (library only) | Yes (if accessed) |
| **Corporate acceptance** | Universal | High | Medium | Lower | Medium | Very low |
| **License complexity** | Very simple | Complex | Medium | Very complex | Very complex | Very complex |
| **Best for** | Libraries, tools | Patent-heavy projects | Core infrastructure | New GPL projects | Libraries | Network services |

---

## Common GPL Misconceptions

### Misconception 1: "GPL means I can't make money"

**False.** GPL allows commercial use and sale.

You can:
- Sell GPL software
- Charge for support and services
- Dual-license (GPL + commercial)
- Offer hosted services

**What you cannot do:**
- Prevent recipients from redistributing
- Prevent recipients from modifying
- Charge for source code (beyond distribution costs)

### Misconception 2: "Using GPL tools makes my output GPL"

**False.** Using GPL compilers, editors, or tools doesn't make your code GPL.

**Example:** Using GCC (GPLv3) to compile proprietary software is fine. The compiler's license doesn't transfer to the compiled output.

**Why:** GPL applies to the program itself, not to its output. Otherwise every Linux program would be GPLv2 (Linux is GPLv2).

### Misconception 3: "GPL is anti-commercial"

**False.** GPL is pro-freedom, not anti-commercial.

Red Hat, SUSE, Canonical, and many others built billion-dollar businesses on GPL software. GPL prevents proprietary capture, not commercialization.

### Misconception 4: "I can't use GPL libraries in my app"

**Partially true, depends on license.**

- GPL library: Linking makes your app GPL
- LGPL library: Linking allowed, app stays proprietary
- Separate process communication: Usually OK

**Solution:** Use LGPL libraries, or dual-license your app (GPL + commercial).

### Misconception 5: "GPL is a contract"

**Debated.** US courts have treated GPL as both copyright license and contract.

**Practical difference:**
- Copyright license: Infringement claim, damages based on copyright law
- Contract: Breach of contract, damages based on contract law

**Result:** GPL enforceable either way. Violators lose license rights.

---

## GPL Compliance Checklist

If you're distributing GPL software, use this checklist:

**Pre-distribution audit:**
- [ ] Identify all GPL components (full dependency scan)
- [ ] Verify GPL version for each component (v2, v3, LGPL, AGPL)
- [ ] Check license compatibility (no GPL-incompatible components)
- [ ] Collect source code for all GPL components
- [ ] Document all modifications made
- [ ] Ensure you can build from source
- [ ] Prepare build instructions

**Distribution package:**
- [ ] Include full GPL license text (COPYING file)
- [ ] Include copyright notices (preserve all headers)
- [ ] Include source code or written offer
- [ ] Include build/installation instructions
- [ ] Mark modified files with prominent notices
- [ ] Include list of all GPL components

**Post-distribution:**
- [ ] Archive source code for 3+ years minimum
- [ ] Respond to source code requests within reasonable time
- [ ] Maintain compliance documentation
- [ ] Update compliance package with each new release
- [ ] Train development team on GPL compliance

**Red flags (indicates potential violation):**
- Missing source code for any GPL component
- Unable to build from provided source
- No written offer when required
- Modified files without notices
- GPL components in proprietary code without LGPL exception

---

## Conclusion: Copyleft's Role in Open Source

GPL represents a fundamentally different approach to software freedom. While permissive licenses (MIT, Apache 2.0) prioritize user freedom (do whatever you want), copyleft licenses prioritize software freedom (the software itself must remain free).

**GPL's legacy:**

**Successes:**
- Linux kernel: unified ecosystem with massive corporate collaboration
- GNU tools: foundation of Unix-like systems
- Prevented proprietary Unix fragmentation
- Forced contributions back to community
- Created sustainable business models (Red Hat, SUSE)

**Limitations:**
- Corporate hesitation (compliance complexity)
- SaaS loophole (GPL doesn't cover network services)
- AGPL too restrictive (many companies ban it)
- Derivative work ambiguity (dynamic linking debates)
- Drove some projects to proprietary licenses (MongoDB, Elastic, Redis)

**When copyleft matters:**

+ Preventing proprietary forks of core infrastructure
+ Ensuring improvements benefit community
+ Projects where collective development is key
+ When network effects favor open standards
+ Ideological commitment to software freedom

**When permissive is better:**

+ Maximizing adoption
+ Enabling commercial SaaS offerings
+ Library meant for wide use
+ Corporate environments
+ Simplicity over enforcement

{{< callout type="info" >}}
**GPL in the modern landscape:** While GPL remains dominant in systems software (Linux, GCC, Git), newer projects increasingly choose permissive licenses (Apache 2.0 for cloud-native, MIT for libraries). The rise of cloud computing exposed GPL's SaaS loophole, and attempts to close it (AGPL, SSPL) have created license fragmentation. GPL's future depends on whether copyleft philosophy remains relevant in a SaaS-dominated world.
{{< /callout >}}

Your licensing choice ultimately depends on your philosophy: do you value maximum freedom for users (MIT), or maximum freedom for the software itself (GPL)?

**Next in series:** Part 4 will cover source-available licenses (BSL, SSPL, Elastic License 2.0) and the controversial trend of open-source companies moving to proprietary licenses.

---

## Further Reading

**Official Resources:**
- [GNU GPL v3 Full Text](https://www.gnu.org/licenses/gpl-3.0.html)
- [GNU GPL v2 Full Text](https://www.gnu.org/licenses/gpl-2.0.html)
- [GNU LGPL v3 Full Text](https://www.gnu.org/licenses/lgpl-3.0.html)
- [GNU AGPL v3 Full Text](https://www.gnu.org/licenses/agpl-3.0.html)
- [FSF Licensing Resources](https://www.gnu.org/licenses/licenses.html)

**Legal Analysis:**
- [GPL Compliance Guide - Software Freedom Conservancy](https://www.softwarefreedom.org/resources/2014/SFLC-Guide_to_GPL_Compliance_2d_ed.pdf)
- [Understanding GPL Compatibility](https://www.gnu.org/licenses/license-compatibility.html)
- [Copyleft Guide - Practical GPL Compliance](https://copyleft.org/)

**Case Law:**
- Versata v. Ameriprise - GPL enforceable in US courts
- [BusyBox GPL Litigation](https://www.softwarefreedom.org/news/2009/dec/14/busybox-gpl-lawsuit/)

**Historical:**
- [Richard Stallman - The GNU Manifesto](https://www.gnu.org/gnu/manifesto.html)
- [Why Copyleft? - FSF](https://www.gnu.org/philosophy/pragmatic.html)

**Related:**
- [Part 1: MIT License Guide](/blog/posts/choosing-mit-license/)
- [Part 2: Apache 2.0 License Guide](/blog/posts/apache-2-license-guide/)
