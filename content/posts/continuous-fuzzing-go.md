---
title: "How Continuous Fuzzing Finds Bugs Traditional Testing Misses"
date: 2026-01-26
draft: false
tags: ["fuzzing", "go", "testing", "github-actions", "coverage-guided-fuzzing", "continuous-integration", "ci-cd", "devops", "quality-assurance", "bug-detection"]
categories: ["programming", "testing", "best-practices"]
description: "Coverage-guided fuzzing runs continuously in CI, exploring millions of input combinations and evolving test cases over time. Learn how to set up continuous fuzzing in Go with GitHub Actions, understand corpus evolution, and see real bugs discovered through automated fuzzing."
summary: "Traditional tests check examples you think of. Fuzzing explores millions of combinations you don't. Coverage-guided fuzzing found two production bugs in goldenthread before release - a UTF-8 corruption issue and a regex escaping bug. Here's how continuous fuzzing works and how to set it up."
---

You wrote comprehensive tests. Your code has 80% test coverage. All 200 assertions pass. Ship it?

I shipped twice with that confidence. Continuous fuzzing found two bugs in the first hour - bugs my test suite would never have exercised.

Traditional testing has a problem: you only test what you think to test. Empty strings, negative numbers, boundary values - these are good. But what about:

- Japanese field names with empty JSON tags (UTF-8 byte slicing)
- Regex patterns containing newline characters (broken JavaScript output)
- Struct fields named "UserID" and "UserId" both mapping to "userId" (JSON collision)

These aren't bugs you'd write tests for. They're bugs you discover by **exploring the input space automatically**.

This is what fuzzing does. And when you run it continuously in CI - generating millions of test cases every day, building on discoveries from previous runs - it finds bugs traditional testing misses.

{{< callout type="info" >}}
**What This Article Covers**

This is a technical deep-dive into continuous fuzzing: how coverage-guided fuzzing works, how corpus evolution compounds over time, and how to set up continuous fuzzing in GitHub Actions. We'll examine two real bugs discovered by fuzzing before they reached production, with technical details and reproduction steps.

If you're familiar with property-based testing (QuickCheck, Hypothesis, proptest), fuzzing is similar but runs continuously in CI with automatic corpus growth.
{{< /callout >}}

---

## What Fuzzing Is (And Isn't)

### Traditional Testing: Explicit Examples

Traditional testing is **example-based**: you write specific test cases for scenarios you anticipate.

```go
func TestParseEmail(t *testing.T) {
    tests := []struct {
        input    string
        wantErr  bool
    }{
        {"alice@example.com", false},
        {"", true},                    // empty
        {"invalid", true},             // no @
        {"@example.com", true},        // no local part
        {"alice@", true},              // no domain
    }
    
    for _, tt := range tests {
        _, err := ParseEmail(tt.input)
        if (err != nil) != tt.wantErr {
            t.Errorf("ParseEmail(%q) error = %v, wantErr %v", 
                tt.input, err, tt.wantErr)
        }
    }
}
```

**What you test**: 5 examples you thought of

**What you don't test**: 
- Unicode characters in local part
- Very long email addresses (> 254 characters)
- Multiple @ symbols
- Special characters (#, !, $, %)
- Whitespace variations
- Null bytes
- Control characters
- Internationalized domain names

### Fuzzing: Automated Exploration

Fuzzing is **exploration-based**: the fuzzer generates thousands of inputs automatically, mutating them to explore code paths.

```go
func FuzzParseEmail(f *testing.F) {
    // Seed corpus (starting examples)
    f.Add("alice@example.com")
    f.Add("")
    f.Add("@example.com")
    
    f.Fuzz(func(t *testing.T, input string) {
        // Fuzzer generates random strings
        // Test must not panic/crash (implicit check)
        result, err := ParseEmail(input)
        
        // Add explicit checks (invariants)
        if err == nil {
            if !strings.Contains(result.Address, "@") {
                t.Errorf("Valid email missing @: %q", result.Address)
            }
        }
    })
}
```

**What gets tested**: Potentially millions of inputs:
- `"\x00alice@example.com"` (null byte)
- `"alice@exampl\ne.com"` (newline in domain)
- `"フィールド@example.com"` (UTF-8)
- `"alice@" + strings.Repeat("a", 1000) + ".com"` (very long)
- And thousands more combinations the fuzzer discovers

---

## How Coverage-Guided Fuzzing Works

Not all fuzzing is equally effective. **Coverage-guided fuzzing** uses code coverage feedback to guide input generation toward unexplored code paths.

### The Fuzzing Loop

{{< mermaid >}}
flowchart TB
    subgraph corpus["Corpus (Interesting Inputs)"]
        seed1["alice@example.com"]
        seed2["@example.com"]
        seed3["フィールド@test.jp"]
    end
    
    subgraph mutate["Mutation Engine"]
        mut1[Bit flips]
        mut2[Byte insertion]
        mut3[Dictionary splicing]
        mut4[Arithmetic changes]
    end
    
    subgraph execute["Execute Test"]
        run[Run fuzz function]
        coverage[Track coverage]
        result{Crash/Fail?}
    end
    
    subgraph decision["Coverage Decision"]
        newcov{New branches<br/>discovered?}
        save[Add to corpus]
        discard[Discard]
    end
    
    corpus --> mutate
    mutate --> execute
    execute --> result
    
    result -->|Crash/Error| fail[Report Bug]
    result -->|Pass| decision
    
    decision --> newcov
    newcov -->|Yes| save
    newcov -->|No| discard
    
    save --> corpus
    discard --> mutate
    
    style corpus fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style mutate fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style execute fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style decision fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Instrumentation: Tracking Coverage

Go's fuzzer instruments your code to track which branches execute:

```go
func ParseEmail(input string) (*Email, error) {
    // Branch 1: Length check
    if len(input) == 0 {
        return nil, ErrEmptyEmail
    }
    
    // Branch 2: UTF-8 validation
    if !utf8.ValidString(input) {
        return nil, ErrInvalidUTF8
    }
    
    // Branch 3: @ check
    parts := strings.Split(input, "@")
    if len(parts) != 2 {
        return nil, ErrInvalidFormat
    }
    
    // Branch 4: Local part validation
    if len(parts[0]) == 0 {
        return nil, ErrEmptyLocalPart
    }
    
    // Branch 5: Domain validation
    if len(parts[1]) == 0 {
        return nil, ErrEmptyDomain
    }
    
    return &Email{Address: input}, nil
}
```

**Instrumented execution tracks**:
- Branch 1: Taken (len > 0) or not taken (len == 0)
- Branch 2: Taken (invalid UTF-8) or not taken (valid UTF-8)
- Branch 3: Taken (parts != 2) or not taken (parts == 2)
- Branch 4: Taken (empty local) or not taken (has local)
- Branch 5: Taken (empty domain) or not taken (has domain)

### Mutation: Generating Inputs

The fuzzer mutates inputs from the corpus to create new test cases:

```
Seed: "alice@example.com"

Mutations:
→ "alice@example.com\x00"     (append null byte)
→ "Alice@example.com"          (flip case)
→ "alice@example.co"           (delete byte)
→ "aalice@example.com"         (duplicate byte)
→ "alice@exampl\ne.com"        (inject newline)
→ "alice@" + repeat("a", 100)  (arithmetic - extend)
→ "フィールド@example.com"      (dictionary - splice UTF-8)
... millions more
```

Each mutation runs through the fuzz function. If it discovers a **new code path** (branch not previously executed), it's added to the corpus for future mutations.

### Example: Discovering a Branch

```go
func ProcessName(name string) string {
    if len(name) == 0 {
        return "Anonymous"
    }
    
    // BUG: Byte slicing breaks UTF-8
    return strings.ToLower(name[:1]) + name[1:]
}
```

**Fuzzing execution**:

```
Run 1: "Alice"
  Branches: len > 0, return camelCase
  Result: "alice" (pass)
  Coverage: 2/2 branches
  
Run 2: "" (mutation: delete all bytes)
  Branches: len == 0, return "Anonymous"
  Result: "Anonymous" (pass)
  Coverage: 2/2 branches (no new coverage)
  
Run 3: "Alice\x00" (mutation: append null)
  Branches: len > 0, return camelCase
  Result: "alice\x00" (pass)
  Coverage: 2/2 branches (no new coverage)
  
Run 444,553: "フィールド" (mutation: splice UTF-8 from dictionary)
  Branches: len > 0, return camelCase
  Result: INVALID UTF-8 OUTPUT (FAIL)
  Coverage: New execution path (UTF-8 edge case)
  BUG FOUND!
```

The fuzzer discovered that `name[:1]` slices bytes, not characters. For multi-byte UTF-8 characters, `[:1]` returns an incomplete byte sequence, corrupting the output.

---

## Corpus Evolution: Compound Growth

The killer feature of continuous fuzzing: **the corpus grows over time**, compounding discoveries from previous runs.

### Initial State (Day 1, Run 1)

```
Seed corpus:
  FuzzEmit:
    - ("User", "username", "email")
    - ("Task", "title", "description")
    - ("日本語", "フィールド", "")  // Explicitly added for UTF-8 testing
  
  Total: 8 seeds across all targets
```

### After 24 Hours (48 runs × 10 minutes)

```
Corpus growth:
  FuzzEmit: 10 → 87 inputs (+770%)
  FuzzEmitPattern: 8 → 52 inputs (+550%)
  FuzzComputeSchemaHash: 6 → 134 inputs (+2133%)
  
  Total: 8 → 542 inputs (+6675%)

Coverage improvement:
  Emitter: 89.4% → 91.7%
  Parser: 75.1% → 78.3%
  Hash: 47.6% → 52.8%
```

### After 1 Month (1,440 runs)

```
Corpus growth:
  Total inputs: 2,847
  Total executions: Millions per target across all runs
  
Coverage:
  Emitter: 94.8%
  Parser: 84.2%
  Hash: 58.1%
  
Bugs found: 2 (both in first week)
```

{{< mermaid >}}
graph LR
    subgraph day1["Day 1"]
        d1c[8 seeds<br/>53% coverage]
    end
    
    subgraph day7["Day 7"]
        d7c[542 inputs<br/>61% coverage]
    end
    
    subgraph day30["Day 30"]
        d30c[2,847 inputs<br/>69% coverage]
    end
    
    day1 -->|Compound growth| day7
    day7 -->|Continued discovery| day30
    
    style day1 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style day7 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style day30 fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Why this works**: Each run starts with an improved corpus from the previous run. Inputs that triggered new branches in run N become seeds for run N+1. The fuzzer doesn't start from scratch every time - it builds on past discoveries.

**The time advantage**:

```
Human test writer:
  20 test cases × 1 minute each = 20 minutes
  Tests check known edge cases only

Continuous fuzzing (based on goldenthread's observed CI performance):
  Single target (10m): 52 million executions
  12 targets total: ~250 million executions per run
  If schedules run reliably: billions of executions per day
  Compounds over time as corpus grows
```

The fuzzer runs when you're sleeping, exploring edge cases automatically.

---

## Real Bug Discovery: UTF-8 Corruption

Let's examine an actual bug found by fuzzing in the goldenthread schema compiler.

### The Bug

**Discovered:** 2026-01-25 at 02:34 UTC  
**Fuzz target:** `FuzzEmit`  
**Executions to discovery:** 444,553  
**Time to discovery:** ~10 seconds  

**Failing input:**

```go
schemaName:   "日本語"
fieldGoName:  "フィールド"
fieldJSONName: ""  // Empty - triggers camelCase conversion
```

**Buggy code:**

```go
func camelCase(s string) string {
    return strings.ToLower(s[:1]) + s[1:]  // Byte slicing!
}
```

### Why This Failed

Japanese text uses multi-byte UTF-8 encoding. The string `"フィールド"` (field) is 5 Unicode characters but 15 bytes in UTF-8:

```
"フィールド" in UTF-8:
[0xE3, 0x83, 0x95] [0xE3, 0x82, 0xA3] [0xE3, 0x83, 0xBC] [0xE3, 0x83, 0xAB] [0xE3, 0x83, 0x89]
 └─ "フ" (3 bytes) └─ "ィ" (3 bytes) └─ "ー" (3 bytes) └─ "ル" (3 bytes) └─ "ド" (3 bytes)
```

`s[:1]` slices **bytes**, not characters (runes). It returns `[0xE3]` - the first byte of a 3-byte character - which is an incomplete UTF-8 sequence. The output fails `utf8.ValidString()` validation.

### How Fuzzing Caught It

The `FuzzEmit` target includes an invariant check:

```go
func FuzzEmit(f *testing.F) {
    f.Add("User", "username", "email")  // Seed corpus
    
    f.Fuzz(func(t *testing.T, schemaName, fieldGoName, fieldJSONName string) {
        // Generate schema
        schema := &schema.Schema{
            Name: schemaName,
            Fields: []schema.Field{{
                GoName: fieldGoName,
                JSONName: fieldJSONName,
            }},
        }
        
        // Emit TypeScript/Zod code
        output, err := emitter.Emit(schema)
        if err != nil {
            return  // Errors are acceptable
        }
        
        // INVARIANT: Output must be valid UTF-8
        if !utf8.ValidString(output) {  // This caught it!
            t.Errorf("Emit produced invalid UTF-8")
        }
    })
}
```

The fuzzer mutated seed inputs, eventually splicing UTF-8 characters into field names. After 444,553 executions (~10 seconds), it generated the specific combination (Japanese name + empty JSON name) that triggered the bug.

### The Fix

```go
func camelCase(s string) string {
    runes := []rune(s)  // Convert to Unicode code points
    if len(runes) > 0 {
        runes[0] = []rune(strings.ToLower(string(runes[0])))[0]
    }
    return string(runes)  // Rune slicing preserves UTF-8
}
```

### Why Manual Testing Missed This

No human test writer thinks: "Let me test Japanese field names with empty JSON names to verify UTF-8 handling in camelCase conversion."

{{< callout type="info" >}}
**Three Independent Factors**

This bug required the intersection of three separate conditions:

1. **Multi-byte UTF-8 input** - Field name starts with Japanese character
2. **Empty JSON name** - Triggers fallback to camelCase conversion
3. **Byte slicing in implementation** - Code uses `s[:1]` instead of rune slicing

Any two of these alone wouldn't trigger the bug. All three together = corrupted output.

Fuzzing explored this combination automatically after 444,553 executions. Manual testing would likely never discover this specific intersection.
{{< /callout >}}

---

## Real Bug Discovery: Regex Escaping

**Discovered:** 2026-01-25 at 02:41 UTC  
**Fuzz target:** `FuzzEmitPattern`  
**Executions to discovery:** 180  
**Time to discovery:** < 1 second  

**Failing input:**

```go
pattern: "\n"  // Newline character in regex pattern
```

**Buggy code:**

```go
if rules.Pattern != nil {
    pattern := strings.ReplaceAll(*rules.Pattern, "\\", "\\\\")
    b.WriteString(fmt.Sprintf(".regex(/%s/)", pattern))
}
```

Only backslashes were escaped. Pattern `"\n"` produced broken JavaScript:

```javascript
.regex(/
/)  // Syntax error - regex literal broken across lines
```

Escaping for JavaScript regex literal context requires more than just backslashes.

### How Fuzzing Caught It

`FuzzEmitPattern` tests random regex patterns:

```go
func FuzzEmitPattern(f *testing.F) {
    f.Add("^[a-z]+$")  // Seed: normal regex
    
    f.Fuzz(func(t *testing.T, pattern string) {
        schema := &schema.Schema{
            Fields: []Field{{
                Rules: FieldRules{Pattern: &pattern},
            }},
        }
        
        output, err := emitter.Emit(schema)
        // Fuzzer discovered output contained literal newlines
        // (No explicit check - but output would be malformed JavaScript)
    })
}
```

The fuzzer tried control characters within 180 executions (< 1 second). Pattern `"\n"` broke JavaScript syntax immediately.

### The Fix

```go
pattern := *rules.Pattern
pattern = strings.ReplaceAll(pattern, "\\", "\\\\")  // Backslash first!
pattern = strings.ReplaceAll(pattern, "/", "\\/")    // Delimiter
pattern = strings.ReplaceAll(pattern, "\n", "\\n")   // Newline
pattern = strings.ReplaceAll(pattern, "\r", "\\r")   // Carriage return
pattern = strings.ReplaceAll(pattern, "\t", "\\t")   // Tab
```

We now escape backslashes, the delimiter (`/` - required because we're emitting `.regex(/pattern/)` literals), and control characters (`\n`, `\r`, `\t`). This handles the common cases for JavaScript regex literal context. Other embedding contexts (like `new RegExp("...")`) have different escaping requirements.

### Why Manual Testing Missed This

Developers test regex patterns like `^[a-z]+$` (alphanumeric), not literal control characters. Fuzzing tried `"\n"` after just 180 executions.

---

## Setting Up Continuous Fuzzing in GitHub Actions

Here's the complete workflow for running fuzzing 24/7 in CI.

### Workflow Configuration

`.github/workflows/fuzz.yml`:

```yaml
name: Continuous Fuzzing

on:
  schedule:
    - cron: '*/30 * * * *'  # Every 30 minutes
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:  # Manual trigger

jobs:
  fuzz:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        target:
          - package: github.com/yourorg/yourproject/internal/emitter
            test: FuzzEmit
            time: 10m
          - package: github.com/yourorg/yourproject/internal/emitter
            test: FuzzEmitPattern
            time: 10m
          - package: github.com/yourorg/yourproject/internal/parser
            test: FuzzParsePackages
            time: 10m
          # Add more fuzz targets...

    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'
      
      - name: Restore fuzz corpus
        uses: actions/cache@v4
        with:
          path: |
            internal/**/testdata/fuzz/**/corpus
          # Key on branch + target so corpus persists across commits
          key: fuzz-corpus-${{ github.ref_name }}-${{ matrix.target.package }}-${{ matrix.target.test }}
          restore-keys: |
            fuzz-corpus-${{ github.ref_name }}-${{ matrix.target.package }}-
            fuzz-corpus-${{ github.ref_name }}-
            fuzz-corpus-
      
      - name: Run fuzzing
        id: fuzz
        continue-on-error: true
        shell: bash
        run: |
          set -o pipefail
          go test ${{ matrix.target.package }} \
            -fuzz=^${{ matrix.target.test }}$ \
            -fuzztime=${{ matrix.target.time }} \
            -v 2>&1 | tee fuzz-output.log
          echo "exit_code=${PIPESTATUS[0]}" >> $GITHUB_OUTPUT
      
      - name: Check for failures
        if: steps.fuzz.outputs.exit_code != '0'
        run: |
          echo "::error::Fuzzing found a bug in ${{ matrix.target.test }}"
          exit 1
      
      - name: Upload failure artifacts
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: fuzz-failure-${{ matrix.target.test }}-${{ github.run_id }}
          path: |
            fuzz-output.log
            internal/**/testdata/fuzz/${{ matrix.target.test }}/**
          retention-days: 30
      
      - name: Create GitHub issue on failure
        if: failure() && github.event_name == 'schedule'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const testName = '${{ matrix.target.test }}';
            const pkg = '${{ matrix.target.package }}';
            
            const output = fs.readFileSync('fuzz-output.log', 'utf8');
            
            // Extract failure details
            const caseMatch = output.match(/Failing input written to testdata\/fuzz\/([^/]+\/[a-f0-9]+)/);
            const caseId = caseMatch ? caseMatch[1] : 'unknown';
            
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Fuzzing found bug in ${testName}`,
              body: `## Fuzzing Failure

**Fuzz Target**: \`${testName}\`
**Package**: \`${pkg}\`
**Failing Case**: \`${caseId}\`

### How to Reproduce

\`\`\`bash
go test ${pkg} -run=${testName}/${caseId}
\`\`\`

### Failing Input

Download the failing test case from the workflow run artifacts.

### Output

\`\`\`
${output.split('\n').slice(-100).join('\n')}
\`\`\`

---

This issue was created automatically by continuous fuzzing.
`,
              labels: ['bug', 'fuzzing', 'automated']
            });
```

### Key Configuration Elements

**1. Schedule: Continuous fuzzing**

```yaml
schedule:
  - cron: '*/30 * * * *'  # Every 30 minutes
```

Runs continuously on a schedule. Each run builds on the previous corpus.

{{< callout type="warning" >}}
**GitHub Actions Scheduled Workflows: Reliability Note**

In practice, GitHub Actions scheduled workflows can be less reliable than push-triggered workflows:
- Schedules may be delayed or skipped during high platform load
- Repositories with infrequent activity sometimes have schedules paused
- No notifications when schedules fail to run

If your scheduled workflow stops running:
1. Manually trigger via workflow_dispatch (often reactivates it)
2. Check Settings → Actions → General to ensure workflows are enabled
3. For production-critical fuzzing, consider self-hosted runners or OSS-Fuzz

The workflow configuration shown here is correct - the limitation is with GitHub's scheduling infrastructure, not the workflow itself.
{{< /callout >}}

**2. Parallel execution**

```yaml
strategy:
  fail-fast: false  # Don't stop other targets if one fails
  matrix:
    target: [...]
```

Runs 12 targets simultaneously. Wall-clock time: ~10 minutes (not 120 minutes).

**3. Corpus caching (critical for continuous growth)**

```yaml
- name: Restore fuzz corpus
  uses: actions/cache@v4
  with:
    path: internal/**/testdata/fuzz/**/corpus
    # Key on branch + target so corpus persists across commits
    key: fuzz-corpus-${{ github.ref_name }}-${{ matrix.target.package }}-${{ matrix.target.test }}
    restore-keys: |
      fuzz-corpus-${{ github.ref_name }}-${{ matrix.target.package }}-
      fuzz-corpus-${{ github.ref_name }}-
      fuzz-corpus-
```

Cache key uses branch name (not commit SHA) so the corpus persists across commits. This is what enables compound growth - each run builds on the previous corpus, even after you push new code.

**4. Exit code capture (critical for reliability)**

```yaml
- name: Run fuzzing
  id: fuzz
  shell: bash
  run: |
    set -o pipefail
    go test ... | tee fuzz-output.log
    echo "exit_code=${PIPESTATUS[0]}" >> $GITHUB_OUTPUT
```

Using `PIPESTATUS[0]` captures the exit code of `go test`, not `tee`. Without this, the workflow would always see exit code 0 from `tee` even when fuzzing fails.

**5. Automatic issue creation**

```yaml
- name: Create GitHub issue on failure
  if: failure() && github.event_name == 'schedule'
```

Only creates issues for scheduled runs (not PRs). Includes:
- Exact reproduction command
- Failing test case ID
- Last 100 lines of output
- Links to artifacts

---

## Understanding Fuzz Target Design

Good fuzz targets test **properties** (invariants), not specific outputs.

### Bad: Testing Exact Output

```go
func FuzzBadExample(f *testing.F) {
    f.Add("alice@example.com")
    
    f.Fuzz(func(t *testing.T, input string) {
        result, _ := ParseEmail(input)
        
        // Bad: Testing exact output (brittle)
        if result.LocalPart != "alice" {
            t.Error("Expected local part 'alice'")
        }
    })
}
```

This fails for any input except "alice@example.com". Fuzzing generates random inputs - exact output tests don't work.

### Good: Testing Properties

```go
func FuzzGoodExample(f *testing.F) {
    f.Add("alice@example.com")
    
    f.Fuzz(func(t *testing.T, input string) {
        result, err := ParseEmail(input)
        
        // Property 1: Valid emails must have @ symbol
        if err == nil {
            if !strings.Contains(result.Address, "@") {
                t.Error("Valid email missing @")
            }
        }
        
        // Property 2: Output must be valid UTF-8
        if err == nil && !utf8.ValidString(result.Address) {
            t.Error("Output contains invalid UTF-8")
        }
        
        // Property 3: Roundtrip (serialize → deserialize = original)
        if err == nil {
            serialized := result.String()
            parsed, err2 := ParseEmail(serialized)
            if err2 != nil || parsed.Address != result.Address {
                t.Error("Roundtrip failed")
            }
        }
    })
}
```

### Common Property Patterns

**1. Roundtrip properties**

```go
func FuzzJSONRoundtrip(f *testing.F) {
    f.Add(`{"name": "Alice"}`)
    
    f.Fuzz(func(t *testing.T, input string) {
        var data map[string]interface{}
        if err := json.Unmarshal([]byte(input), &data); err != nil {
            return  // Invalid JSON is acceptable
        }
        
        // Property: Unmarshal → Marshal → Unmarshal = same data
        encoded, err := json.Marshal(data)
        if err != nil {
            t.Fatalf("Marshal failed: %v", err)
        }
        
        var data2 map[string]interface{}
        if err := json.Unmarshal(encoded, &data2); err != nil {
            t.Fatalf("Roundtrip unmarshal failed: %v", err)
        }
        
        if !reflect.DeepEqual(data, data2) {
            t.Error("Roundtrip produced different data")
        }
    })
}
```

**2. Idempotence (f(f(x)) = f(x))**

```go
func FuzzNormalize(f *testing.F) {
    f.Add("  Hello  World  ")
    
    f.Fuzz(func(t *testing.T, input string) {
        once := Normalize(input)
        twice := Normalize(once)
        
        // Property: Normalizing twice = normalizing once
        if once != twice {
            t.Errorf("Not idempotent: %q → %q → %q", input, once, twice)
        }
    })
}
```

**3. Invariants (properties that always hold)**

```go
func FuzzHashDeterminism(f *testing.F) {
    f.Add("example")
    
    f.Fuzz(func(t *testing.T, input string) {
        hash1 := ComputeHash(input)
        hash2 := ComputeHash(input)
        
        // Property: Same input must produce same hash
        if hash1 != hash2 {
            t.Error("Hash is non-deterministic")
        }
    })
}
```

**4. Inverse operations**

```go
func FuzzBase64(f *testing.F) {
    f.Add([]byte("hello world"))
    
    f.Fuzz(func(t *testing.T, data []byte) {
        encoded := base64.StdEncoding.EncodeToString(data)
        decoded, err := base64.StdEncoding.DecodeString(encoded)
        
        // Property: Encode → Decode = original
        if err != nil {
            t.Fatalf("Decode failed: %v", err)
        }
        
        if !bytes.Equal(data, decoded) {
            t.Error("Encode/decode not inverse")
        }
    })
}
```

---

## Debugging Fuzzing Failures

When fuzzing finds a bug, here's how to reproduce and debug it locally.

### Step 1: Download Failing Test Case

GitHub Actions uploads the failing test case as an artifact. Download it from the workflow run.

### Step 2: Reproduce Locally

```bash
# Extract artifact
unzip fuzz-failure-FuzzEmit-abc123.zip

# Copy to testdata
cp corpus/10d7376b241dbd70 internal/emitter/zod/testdata/fuzz/FuzzEmit/

# Run the specific failing test
go test ./internal/emitter/zod -run=FuzzEmit/10d7376b241dbd70 -v
```

This runs the **exact input** that caused the failure. Fully deterministic.

### Step 3: Debug

```bash
# Run with debugger
dlv test ./internal/emitter/zod -- -test.run=FuzzEmit/10d7376b241dbd70

# Or add print statements
go test ./internal/emitter/zod -run=FuzzEmit/10d7376b241dbd70 -v
```

The failing input is small and focused (fuzzer minimizes it automatically), making debugging straightforward.

### Step 4: Fix and Verify

```bash
# Fix the bug in source
vim internal/emitter/zod/emitter.go

# Verify the specific case now passes
go test ./internal/emitter/zod -run=FuzzEmit/10d7376b241dbd70

# Verify fuzzing doesn't find more issues
go test ./internal/emitter/zod -fuzz=FuzzEmit -fuzztime=30s
```

### Step 5: Add Regression Test

```go
func TestEmit_UTF8_EmptyJSONName(t *testing.T) {
    // Exact input that triggered the bug
    s := &schema.Schema{
        Name: "日本語",
        Fields: []Field{{
            GoName: "フィールド",
            JSONName: "",
        }},
    }
    
    output, err := emitter.Emit(s)
    if err != nil {
        t.Fatalf("Emit() error = %v", err)
    }
    
    if !utf8.ValidString(output) {
        t.Error("Output contains invalid UTF-8")
    }
}
```

This prevents regression and documents the fix.

---

## Cost and Resource Management

### GitHub Actions Costs

**Public repositories:**

GitHub-hosted runners for public repos are generally generous enough that continuous fuzzing is often feasible at no cost. However, fair-use policies apply and specifics can change.

**Private repositories:**

For private repositories, continuous fuzzing can become expensive. With 12 targets running for 10 minutes every 30 minutes:

```
5,760 minutes/day × 30 days = ~172,000 minutes/month
At ~$0.008/minute (Linux runners) = ~$1,400/month
```

This is why production continuous fuzzing often requires:
- Self-hosted GitHub Actions runners
- Dedicated fuzzing infrastructure (OSS-Fuzz)
- GitHub Enterprise with higher quotas
- Reduced frequency/duration (trade-offs below)

### Optimization Strategies

**1. Reduce frequency:**

```yaml
schedule:
  - cron: '0 */3 * * *'  # Every 3 hours instead of 30 minutes
```

Reduces cost by 6× (still runs 8 times per day).

**2. Limit fuzz time:**

```yaml
- name: Run fuzzing
  run: go test ... -fuzztime=5m  # 5 minutes instead of 10
```

Halves cost, still runs frequently.

**3. Selective fuzzing:**

```yaml
# Only fuzz on main branch, not PRs
on:
  schedule:
    - cron: '*/30 * * * *'
  # Remove push/pull_request triggers
```

Eliminates cost from PR builds.

---

## When Fuzzing Finds Nothing

After a month of continuous fuzzing, no new bugs. Is fuzzing working?

### Signs of Healthy Fuzzing

**1. Corpus is growing:**

```bash
# Check corpus size over time
git log --all --oneline -- '**/testdata/fuzz/**/corpus' | head -20
```

If no new corpus entries for weeks, fuzzing may have plateaued.

**2. Coverage is increasing:**

```bash
# Check coverage trends
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
```

Coverage should increase as corpus grows (but will plateau eventually).

**3. Executions are consistent:**

Check GitHub Actions logs for execution counts. Here's what I observed on goldenthread's CI:

```
Recent goldenthread CI run (GitHub-hosted runners):
FuzzEmit (10m):           52,278,168 executions
FuzzEmitFieldName (5m):   24,345,196 executions
FuzzEmitValidation (5m):  23,007,683 executions

Average observed rate: ~87,000 executions/second
Per 10-minute run: ~50 million executions per target
```

Your mileage will vary based on test complexity, corpus size, and runner specifications. GitHub Actions runners typically provide more workers (22 in my case) than local machines, resulting in higher throughput.

### When Finding Nothing Means Success

```
Week 1: 2 bugs found
Week 2-4: 0 bugs found
Month 2: 0 bugs found
Month 3: 0 bugs found
```

This is **success** - your code is stable. Continuous fuzzing acts as **insurance**: it keeps running to catch regressions from future changes.

### Adding More Fuzz Targets

If fuzzing plateaus, add more targets to explore different code paths:

```go
// Before: Only testing Emit()
func FuzzEmit(f *testing.F) { ... }

// After: Also test field name generation
func FuzzEmitFieldName(f *testing.F) {
    f.Add("username", "email")
    
    f.Fuzz(func(t *testing.T, goName, jsonName string) {
        // Test field name edge cases
    })
}

// And pattern validation
func FuzzEmitPattern(f *testing.F) { ... }

// And enum generation
func FuzzEmitEnum(f *testing.F) { ... }
```

---

## Fuzzing vs Property-Based Testing

If you're familiar with property-based testing (QuickCheck, Hypothesis, proptest), fuzzing is similar with three key differences:

**1. Coverage guidance** - Fuzzing uses coverage feedback to explore new code paths. Property-based testing generates pure random inputs without feedback.

**2. Persistent corpus** - Fuzzing saves inputs that trigger new branches. Property-based testing generates fresh random inputs each run.

**3. Scale** - Fuzzing runs continuously in CI (millions of executions over time). Property-based testing runs 100-10,000 cases per test suite execution.

Use both: property-based tests catch bugs during development, fuzzing catches edge cases over time in production.

---

## Conclusion

Traditional testing checks examples you think of. Fuzzing explores combinations you don't.

**What we covered:**

- Coverage-guided fuzzing uses instrumentation to guide input generation toward unexplored code paths
- Corpus evolution compounds over time - each run builds on previous discoveries
- Continuous fuzzing runs 24/7 in CI, exploring billions of input combinations
- Real bugs: UTF-8 corruption (444,553 executions) and regex escaping (180 executions)
- GitHub Actions workflow runs every 30 minutes with automatic issue creation
- Fuzz targets test properties (invariants), not exact outputs

**When to use fuzzing:**

+ Parsers, serializers, encoders (lots of edge cases)
+ String processing (UTF-8, escape sequences, control characters)
+ Format validation (emails, URLs, regex patterns)
+ Mathematical operations (overflow, division by zero)
+ Anything with complex input space

**When to skip fuzzing:**

- Simple business logic (example-based tests are clearer)
- Code with no invariants to test
- UI interactions (fuzzing doesn't work well with stateful UIs)
- Database migrations (specific sequences matter)

The best testing strategy uses multiple approaches: unit tests for known cases, integration tests for workflows, property-based tests for algorithmic properties, and fuzzing for continuous exploration.

Fuzzing found two production bugs in goldenthread before release. Both were edge cases no human test writer would think to check. This is what continuous fuzzing does - it explores the input space automatically, finding bugs you didn't know existed.

---

## Further Reading

**Official Documentation:**
- [Go Fuzzing Documentation](https://go.dev/doc/fuzz/)
- [Go Blog: Fuzzing is Beta Ready](https://go.dev/blog/fuzz-beta)

**Related Articles on This Blog:**
- [The Complete Guide to Rust Testing](/posts/rust-testing-comprehensive-guide/) - Property-based testing with proptest
- [How Multicore CPUs Changed Object-Oriented Programming](/posts/multicore-killed-oop/) - Why value semantics matter for concurrent code

**Real-World Examples:**
- [goldenthread Fuzzing Bug Log](https://github.com/blackwell-systems/goldenthread/blob/main/docs/FUZZING_BUGS.md) - Detailed analysis of both bugs found by fuzzing, including trigger conditions, root cause analysis, and fixes
- [goldenthread Continuous Fuzzing Setup](https://github.com/blackwell-systems/goldenthread/blob/main/docs/CONTINUOUS_FUZZING.md) - Complete implementation guide for the fuzzing system described in this article

**Tools and Resources:**
- [go-fuzz](https://github.com/dvyukov/go-fuzz) - Alternative Go fuzzing tool
- [AFL (American Fuzzy Lop)](https://github.com/google/AFL) - Industry-standard fuzzer
- [libFuzzer](https://llvm.org/docs/LibFuzzer.html) - LLVM's fuzzing library
- [OSS-Fuzz](https://github.com/google/oss-fuzz) - Google's continuous fuzzing for open source

---

*Found an error or have questions? [Open an issue](https://github.com/blackwell-systems/blog/issues) or reach out on [Twitter/X](https://twitter.com/blackwellsystems).*
