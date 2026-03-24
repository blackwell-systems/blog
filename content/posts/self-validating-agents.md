---
title: "Self-Validating Agents: Building Quality Checks into Claude Code Workflows"
date: 2025-03-24
draft: false
tags: ["claude-code", "ai-agents", "automation", "quality-assurance", "hooks", "validation", "testing", "linting", "workflows", "developer-tools", "agent-orchestration", "code-quality", "cicd", "yaml", "settings", "posttooluse", "stop-hooks", "team-agents", "typescript", "python", "rust", "go"]
categories: ["developer-tools", "automation"]
description: "Three-tier validation system for Claude Code agents: PostToolUse hooks for instant feedback, Stop hooks for structural requirements, and read-only validator agents for independent review. Build agents that catch their own mistakes."
summary: "Claude Code agents write code fast. Too fast to catch quality issues in real-time. Here's how to build validation directly into agent workflows using hooks and team coordination - micro validation after every file write, macro validation before completion, and independent review from validator agents."
---

Claude Code agents move fast. An agent can scaffold a feature, write tests, update documentation, and commit changes in minutes. That speed is valuable, but it comes with a problem: agents can complete tasks before you notice quality issues.

The solution is self-validation. Instead of reviewing every agent action manually, build quality checks directly into the workflow. Claude Code provides three mechanisms for this, each operating at a different scope.

## The Three Tiers of Validation

Self-validating agents use a layered approach to quality control:

**Micro Validation (PostToolUse Hooks)** - Runs linters, formatters, and type checkers immediately after each file write. Catches syntax errors and style violations before the agent moves on.

**Macro Validation (Stop Hooks)** - Checks structural requirements before agent completion. Validates that required files exist, tests pass, and build succeeds. Blocks task completion if validation fails.

**Team Validation (Read-Only Validator Agents)** - A separate agent reviews the builder's output without modifying files. Provides independent assessment of code quality, architecture decisions, and implementation completeness.

Each tier addresses a different failure mode. Micro validation catches immediate errors. Macro validation ensures completeness. Team validation provides architectural review.

{{< mermaid >}}
flowchart TB
    subgraph micro["Micro Validation - PostToolUse Hooks"]
        WRITE[Agent Writes File]
        HOOK[Hook Executes]
        LINT[Run Linter]
        FORMAT[Run Formatter]
        TYPE[Type Check]
        WRITE --> HOOK
        HOOK --> LINT
        HOOK --> FORMAT
        HOOK --> TYPE
    end

    subgraph macro["Macro Validation - Stop Hooks"]
        STOP[Agent Signals Stop]
        CHECK[Stop Hook Runs]
        BUILD[Build Succeeds?]
        TEST[Tests Pass?]
        FILES[Required Files?]
        CHECK --> BUILD
        CHECK --> TEST
        CHECK --> FILES
    end

    subgraph team["Team Validation - Validator Agent"]
        REVIEW[Validator Agent]
        ARCH[Architecture Review]
        QUALITY[Code Quality Check]
        COMPLETE[Completeness Check]
        REVIEW --> ARCH
        REVIEW --> QUALITY
        REVIEW --> COMPLETE
    end

    micro --> macro
    macro --> team

    style micro fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style macro fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style team fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

## Micro Validation: PostToolUse Hooks

PostToolUse hooks execute immediately after specific tool calls. For file operations, this means running quality checks the moment a file is written or edited.

### Basic Hook Configuration

Hooks are configured in Claude Code's `settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

This runs Black (Python formatter) after every `Write` or `Edit` tool call. The `$CLAUDE_TOOL_INPUT_FILE_PATH` variable contains the path to the file that was just written.

### Multiple Validators in Sequence

Chain multiple validators to enforce different quality standards:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          },
          {
            "type": "command",
            "command": "mypy \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          },
          {
            "type": "command",
            "command": "pylint \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

The agent writes a file. Black formats it. Mypy type-checks it. Pylint analyzes it. All three run automatically before the agent continues.

### Language-Specific Validation

Different languages need different validators. Use file extension matching to route appropriately:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "filter": "*.py$",
        "hooks": [
          {
            "type": "command",
            "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\" && mypy \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": "*.ts$",
        "hooks": [
          {
            "type": "command",
            "command": "prettier --write \"$CLAUDE_TOOL_INPUT_FILE_PATH\" && eslint \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": "*.rs$",
        "hooks": [
          {
            "type": "command",
            "command": "rustfmt \"$CLAUDE_TOOL_INPUT_FILE_PATH\" && cargo clippy --quiet"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": "*.go$",
        "hooks": [
          {
            "type": "command",
            "command": "gofmt -w \"$CLAUDE_TOOL_INPUT_FILE_PATH\" && go vet \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

Python files get Black and mypy. TypeScript gets Prettier and ESLint. Rust gets rustfmt and clippy. Go gets gofmt and vet. The hooks system routes validation automatically based on file extension.

### When Hooks Fail

If a hook command exits with non-zero status, Claude Code displays the error output. The agent sees the validation failure and can respond:

- Fixing the issue immediately
- Adjusting the code to pass validation
- Explaining why the validation error is acceptable in this context

The agent learns from validation failures. If Black reformats code differently than the agent wrote it, the agent sees the diff and adjusts its output style in subsequent files.

{{< callout type="info" >}}
PostToolUse hooks are synchronous. The agent waits for hook completion before continuing. Fast validators (formatters, linters) work well. Slow validators (full test suites, extensive static analysis) should run in macro validation instead.
{{< /callout >}}

## Macro Validation: Stop Hooks

PostToolUse hooks validate individual files. Stop hooks validate the entire work product before the agent signals completion.

### Basic Stop Hook

A stop hook runs when the agent calls the `Stop` tool or completes a task:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "make test"
          }
        ]
      }
    ]
  }
}
```

If `make test` fails, the stop hook blocks task completion. The agent must fix test failures before it can mark the task done.

### Structural Validation

Check that required files exist and meet specific criteria:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash -c '[[ -f README.md ]] && [[ -f setup.py ]] && [[ -f requirements.txt ]]'"
          },
          {
            "type": "command",
            "command": "python -m py_compile setup.py"
          },
          {
            "type": "command",
            "command": "pip install --dry-run -r requirements.txt"
          }
        ]
      }
    ]
  }
}
```

This validates:
1. Required files (README.md, setup.py, requirements.txt) exist
2. setup.py is valid Python
3. requirements.txt dependencies are resolvable

If any check fails, the agent cannot complete the task. It must create missing files or fix broken dependencies.

### Build Validation

Ensure the project builds before allowing completion:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cargo build --all-features"
          },
          {
            "type": "command",
            "command": "cargo test --all-features"
          },
          {
            "type": "command",
            "command": "cargo clippy --all-features -- -D warnings"
          }
        ]
      }
    ]
  }
}
```

For a Rust project, this enforces:
- Build succeeds with all features enabled
- All tests pass
- No clippy warnings (promoted to errors with `-D warnings`)

The agent cannot mark the task complete until all three conditions are met.

### Test Coverage Requirements

Enforce minimum test coverage:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pytest --cov=src --cov-fail-under=80"
          }
        ]
      }
    ]
  }
}
```

If test coverage drops below 80%, the stop hook fails. The agent must add tests before completion.

### Documentation Validation

Check that documentation exists and is valid:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "markdownlint README.md docs/*.md"
          },
          {
            "type": "command",
            "command": "cargo doc --no-deps"
          }
        ]
      }
    ]
  }
}
```

This validates markdown formatting and ensures Rust documentation builds without errors.

{{< mermaid >}}
sequenceDiagram
    participant Agent
    participant Stop Hook
    participant Build System
    participant Tests
    participant Linters

    Agent->>Agent: Complete implementation
    Agent->>Stop Hook: Signal stop
    Stop Hook->>Build System: Run build
    Build System-->>Stop Hook: Success
    Stop Hook->>Tests: Run test suite
    Tests-->>Stop Hook: Success
    Stop Hook->>Linters: Run linters
    Linters-->>Stop Hook: Success
    Stop Hook-->>Agent: All checks passed
    Agent->>Agent: Mark task complete

    Note over Agent,Linters: If any check fails, agent must fix before stopping
{{< /mermaid >}}

## Team Validation: Read-Only Validator Agents

PostToolUse hooks validate syntax. Stop hooks validate structure. Neither provides architectural review or assesses whether the implementation actually solves the problem correctly.

That's what validator agents do.

### Validator Agent Pattern

A validator agent is a separate agent with read-only permissions that reviews another agent's work:

```yaml
# agents/validator.yaml
name: validator
description: Reviews code for quality, architecture, and completeness
permissions:
  - Read
  - Glob
  - Grep
instructions: |
  You are a code reviewer. Your job is to assess code quality, architectural
  decisions, and implementation completeness. You cannot modify files - only
  review them.

  For each review:
  1. Read all modified files
  2. Check architectural decisions against project standards
  3. Verify edge cases are handled
  4. Assess test coverage
  5. Identify potential bugs or issues
  6. Provide actionable feedback

  Your review should be constructive and specific. Point to exact file locations
  when identifying issues.
```

The validator agent has `Read`, `Glob`, and `Grep` permissions but not `Write` or `Edit`. It can examine the codebase but cannot change it.

### Using the Validator Agent

After the builder agent completes a feature:

```bash
# Builder agent completes work
claude --agent builder

# Validator agent reviews
claude --agent validator
```

The validator agent reads the changes, assesses quality, and provides a review. If issues are found, the builder agent can address them in a follow-up session.

### Validation Checklist

Give the validator agent a specific checklist to work through:

```yaml
instructions: |
  Review the implementation against this checklist:

  **Architecture**
  - Does the solution match project patterns?
  - Are dependencies appropriate?
  - Is the module structure clean?

  **Error Handling**
  - Are errors propagated correctly?
  - Are edge cases handled?
  - Is error context preserved?

  **Testing**
  - Do tests cover happy path?
  - Are edge cases tested?
  - Are error conditions tested?

  **Documentation**
  - Is public API documented?
  - Are complex algorithms explained?
  - Is the README updated if needed?

  **Code Quality**
  - Are variable names clear?
  - Is there duplicated code that should be extracted?
  - Are functions appropriately sized?

  For each item, provide specific feedback with file and line references.
```

This gives the validator agent a structured framework for review.

### Automated Validator Invocation

Use a stop hook to automatically invoke the validator agent:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "claude --agent validator --prompt 'Review the changes made by the builder agent'"
          }
        ]
      }
    ]
  }
}
```

When the builder agent signals completion, the stop hook automatically launches the validator agent for review.

{{< callout type="warning" >}}
Validator agents increase task completion time. Use them for critical features where independent review is valuable. Not every file write needs a full architectural review.
{{< /callout >}}

## Combining Validation Tiers

The three validation tiers work together to create a comprehensive quality system:

{{< mermaid >}}
flowchart LR
    subgraph write["File Write"]
        W[Agent Writes File]
    end

    subgraph micro["Micro - Immediate"]
        F[Format]
        L[Lint]
        T[Type Check]
    end

    subgraph continue["Agent Continues"]
        C[Next File]
    end

    subgraph stop["Agent Completes"]
        S[Signal Stop]
    end

    subgraph macro["Macro - Structural"]
        B[Build]
        TS[Test Suite]
        COV[Coverage Check]
    end

    subgraph team["Team - Review"]
        V[Validator Agent]
        R[Architecture Review]
        FB[Feedback]
    end

    W --> F
    F --> L
    L --> T
    T --> C
    C --> W

    C --> S
    S --> B
    B --> TS
    TS --> COV
    COV --> V
    V --> R
    R --> FB

    style write fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style micro fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style continue fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style stop fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style macro fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style team fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

1. Agent writes a file
2. PostToolUse hook runs (format, lint, type check)
3. Agent continues to next file
4. When all files are written, agent signals stop
5. Stop hook runs (build, test suite, coverage)
6. If stop hook passes, validator agent reviews
7. Validator provides feedback

Each tier catches different issues:
- **Micro**: Syntax errors, style violations, type errors
- **Macro**: Build failures, test failures, missing files
- **Team**: Architectural issues, incomplete solutions, edge cases

## Real-World Example: Python API Service

Here's a complete validation setup for a Python API service:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "filter": "\\.py$",
        "hooks": [
          {
            "type": "command",
            "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          },
          {
            "type": "command",
            "command": "mypy --strict \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          },
          {
            "type": "command",
            "command": "pylint --disable=C0111 \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pytest --cov=src --cov-fail-under=80 --cov-report=term-missing"
          },
          {
            "type": "command",
            "command": "python -m py_compile src/**/*.py"
          },
          {
            "type": "command",
            "command": "bash -c '[[ -f requirements.txt ]] && [[ -f README.md ]] && [[ -f tests/test_*.py ]]'"
          }
        ]
      }
    ]
  }
}
```

And the validator agent:

```yaml
# agents/python-validator.yaml
name: python-validator
description: Reviews Python API implementations
permissions:
  - Read
  - Glob
  - Grep
instructions: |
  Review Python API implementations for quality and correctness.

  **API Design**
  - Are endpoints RESTful?
  - Is error handling consistent?
  - Are status codes appropriate?
  - Is authentication/authorization correct?

  **Python Patterns**
  - Are type hints complete and accurate?
  - Is exception handling appropriate?
  - Are resources properly closed (context managers)?
  - Is async/await used correctly if applicable?

  **Testing**
  - Are all endpoints tested?
  - Are error cases tested?
  - Are edge cases covered?
  - Is mocking appropriate?

  **Security**
  - Is input validation present?
  - Are SQL injections prevented?
  - Is sensitive data logged?
  - Are dependencies up to date?

  Provide specific feedback with file and line references.
```

This setup catches:
- Formatting issues immediately (Black)
- Type errors immediately (mypy)
- Code quality issues immediately (pylint)
- Build failures before completion (py_compile)
- Test failures before completion (pytest)
- Missing requirements before completion (file checks)
- Architectural issues after completion (validator agent)

## When Not to Use Self-Validation

Self-validation adds overhead. Not every workflow needs it.

**Skip self-validation when:**
- Prototyping or exploring
- Writing throwaway code
- Making documentation-only changes
- Working on personal projects where you are the only reviewer
- The validation overhead exceeds the error cost

**Use self-validation when:**
- Multiple developers work on the codebase
- Code quality standards are enforced
- Agents work autonomously without immediate review
- The cost of bugs is high (production systems, critical infrastructure)
- You want to train agents on project-specific patterns

The decision is about error cost versus validation overhead. High-stakes production code benefits from all three validation tiers. Experimental prototypes need none.

## Performance Considerations

Each validation tier has different performance characteristics:

| Tier | Execution Time | Frequency | Impact |
|------|---------------|-----------|--------|
| Micro (PostToolUse) | Milliseconds to seconds | Every file write | Minimal if validators are fast |
| Macro (Stop) | Seconds to minutes | Once per task | Moderate, blocks completion |
| Team (Validator) | Minutes | Once per review request | High, separate agent session |

**Optimization strategies:**

**For micro validation:**
- Use fast formatters and linters
- Avoid running full test suites in PostToolUse hooks
- Skip validation for temporary or generated files
- Consider file-local checks only (not project-wide)

**For macro validation:**
- Run tests in parallel if possible
- Use incremental builds
- Cache dependencies
- Consider running only affected tests

**For team validation:**
- Reserve for significant features or complex changes
- Don't invoke for every small fix
- Use async review (don't block builder agent)
- Provide clear review criteria to minimize back-and-forth

{{< mermaid >}}
flowchart TB
    subgraph fast["Fast Validation - Micro"]
        F1[Black: 100ms]
        F2[mypy: 500ms]
        F3[pylint: 800ms]
        TOTAL1[Total: ~1.4s per file]
    end

    subgraph moderate["Moderate Validation - Macro"]
        M1[Build: 5s]
        M2[Tests: 30s]
        M3[Coverage: 2s]
        TOTAL2[Total: ~37s per task]
    end

    subgraph slow["Slow Validation - Team"]
        S1[Read Files: 10s]
        S2[Analysis: 60s]
        S3[Generate Report: 15s]
        TOTAL3[Total: ~85s per review]
    end

    style fast fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style moderate fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style slow fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

## Agent-Scoped Validation

Different agents can have different validation rules. A builder agent might need strict validation, while an exploration agent needs flexibility.

```json
{
  "agents": [
    {
      "name": "builder",
      "hooks": {
        "PostToolUse": [
          {
            "matcher": "Write|Edit",
            "hooks": [
              {
                "type": "command",
                "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\" && mypy \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
              }
            ]
          }
        ],
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "pytest --cov=src --cov-fail-under=80"
              }
            ]
          }
        ]
      }
    },
    {
      "name": "explorer",
      "hooks": {
        "PostToolUse": [
          {
            "matcher": "Write|Edit",
            "hooks": [
              {
                "type": "command",
                "command": "python -m py_compile \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
              }
            ]
          }
        ]
      }
    }
  ]
}
```

The builder agent has strict validation (formatting, type checking, test coverage). The explorer agent has minimal validation (syntax check only).

This lets you match validation strictness to agent purpose:
- **Builder agents**: Strict validation, enforces project standards
- **Explorer agents**: Minimal validation, maximizes speed
- **Refactor agents**: Moderate validation, ensures no regressions
- **Documentation agents**: Light validation, checks markdown only

## Decision Framework: Which Validation Tier?

Use this framework to choose appropriate validation:

```
Is the error immediately obvious to the agent?
├─ Yes: Micro validation (PostToolUse hook)
└─ No: Is the error structural?
    ├─ Yes: Macro validation (Stop hook)
    └─ No: Is the error architectural?
        ├─ Yes: Team validation (Validator agent)
        └─ No: Manual review
```

**Micro validation examples:**
- Syntax errors
- Import errors
- Type mismatches
- Style violations
- Missing semicolons or braces

**Macro validation examples:**
- Missing required files
- Build failures
- Test failures
- Integration issues
- Dependency conflicts

**Team validation examples:**
- Poor architectural decisions
- Incomplete solutions
- Missing edge cases
- Security vulnerabilities
- Code duplication across modules

## Common Validation Patterns

### Pattern: Incremental Strictness

Start with minimal validation, increase as code matures:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "filter": "src/.*\\.py$",
        "hooks": [
          {
            "type": "command",
            "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          },
          {
            "type": "command",
            "command": "mypy --strict \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": "prototype/.*\\.py$",
        "hooks": [
          {
            "type": "command",
            "command": "python -m py_compile \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

Files in `src/` get strict validation. Files in `prototype/` get basic syntax checking only.

### Pattern: Validation Escape Hatch

Allow the agent to skip validation for specific cases:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "filter": ".*\\.py$",
        "hooks": [
          {
            "type": "command",
            "command": "grep -q '# SKIP_VALIDATION' \"$CLAUDE_TOOL_INPUT_FILE_PATH\" || black \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

If the agent adds `# SKIP_VALIDATION` to a file, validation is skipped. Useful for generated code or temporary workarounds.

### Pattern: Fail Fast, Fix Fast

Run cheap validators first, expensive ones last:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python -m py_compile src/**/*.py"
          },
          {
            "type": "command",
            "command": "pytest tests/unit/"
          },
          {
            "type": "command",
            "command": "pytest tests/integration/"
          }
        ]
      }
    ]
  }
}
```

Syntax check takes seconds. Unit tests take minutes. Integration tests take longer. If syntax is broken, fail immediately without running expensive tests.

### Pattern: Context-Aware Validation

Different validation for different file types:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "filter": ".*\\.py$",
        "hooks": [
          {
            "type": "command",
            "command": "black \"$CLAUDE_TOOL_INPUT_FILE_PATH\" && mypy \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": ".*\\.md$",
        "hooks": [
          {
            "type": "command",
            "command": "markdownlint \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": ".*\\.yaml$",
        "hooks": [
          {
            "type": "command",
            "command": "yamllint \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "filter": "Dockerfile$",
        "hooks": [
          {
            "type": "command",
            "command": "hadolint \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

Python files get Black and mypy. Markdown files get markdownlint. YAML files get yamllint. Dockerfiles get hadolint. Each file type gets appropriate validation.

## Debugging Validation Failures

When a validation hook fails, the agent sees the error output. Common patterns:

**Formatter disagreement:**
```
black would reformat /path/to/file.py
```

The agent can read the file, see Black's preferred formatting, and adjust its style in future writes.

**Type error:**
```
file.py:42: error: Argument 1 to "process" has incompatible type "str"; expected "int"
```

The agent sees the exact line and error, can fix the type issue.

**Test failure:**
```
FAILED tests/test_api.py::test_user_creation - AssertionError: Expected 201, got 400
```

The agent can read the test, understand what failed, and fix the implementation.

**Build failure:**
```
error: could not compile `project` due to previous error
```

The agent sees the compiler error and can address the root cause.

{{< callout type="info" >}}
Hook failures are learning signals. The agent uses validation output to understand project standards and improve its output over time. Consistent validation helps agents converge on project-specific patterns faster.
{{< /callout >}}

## Validation Best Practices

**Keep validators fast.** PostToolUse hooks run on every file write. A 30-second validator means the agent waits 30 seconds after every file. Use fast formatters and linters in PostToolUse hooks, save expensive checks for Stop hooks.

**Provide clear error messages.** Validators that output "Error: validation failed" don't help the agent fix the issue. Validators that output "Line 42: Missing type annotation on return value" give the agent specific direction.

**Fail with non-zero exit codes.** Hook commands that always exit with 0 won't signal failures. Ensure validators exit non-zero on errors.

**Test your validators.** Run validators manually to confirm they catch the issues you care about and provide useful output.

**Version validation rules with code.** Hooks configuration lives in `settings.json`, which should be version controlled. When validation rules change, the change is tracked alongside code changes.

**Document validation requirements.** Add a section to your README or CONTRIBUTING.md explaining what validators run and why. This helps human developers understand quality expectations too.

**Consider validator maintenance.** Validators need updates (dependency updates, rule changes). Budget time for maintaining validation infrastructure.

**Balance strictness with productivity.** Validation that blocks every minor style choice frustrates agents and developers. Focus validation on issues that actually matter to code quality and correctness.

## Integration with CI/CD

Self-validating agents catch issues before code reaches CI/CD. But CI should still run the same checks:

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Format check
        run: black --check src/
      - name: Type check
        run: mypy --strict src/
      - name: Lint
        run: pylint src/
      - name: Test
        run: pytest --cov=src --cov-fail-under=80
```

The CI pipeline runs the same validators as the agent's hooks. This ensures:
- Human commits meet the same standards as agent commits
- Validation runs even if local hooks are disabled
- Pull requests are validated before merge
- The main branch stays clean

The difference: agent hooks catch issues in seconds during development. CI catches issues in minutes after pushing. Agent validation is the first line of defense, CI is the second.

## Limitations and Tradeoffs

Self-validation has costs:

**Performance overhead.** Every validation hook adds latency. Fast validators (formatters) add milliseconds. Slow validators (full test suites) add minutes. Balance validation thoroughness against agent speed.

**False positives.** Strict validators sometimes flag correct code. If a validator complains about valid code, the agent must either fix the code to satisfy the validator or explain why the validator is wrong. Both cost time.

**Configuration complexity.** A comprehensive validation setup requires careful hook configuration, agent definitions, and validator scripts. This is maintenance burden.

**Limited architectural insight.** Hooks can validate syntax and structure. They cannot assess whether the solution actually solves the problem correctly. That still requires human or validator agent review.

**Brittleness.** If a validator has bugs or the validation environment is misconfigured, validation fails even on correct code. Debugging validation infrastructure can be frustrating.

The tradeoff: validation catches more errors automatically but requires upfront investment in configuration and maintenance.

## The Validation Pyramid

Think of validation as a pyramid:

```
           /\
          /  \           Team Validation
         /    \          (Architectural Review)
        /      \         Slow, Deep, Infrequent
       /        \
      /----------\       Macro Validation
     /            \      (Build, Test, Structure)
    /              \     Moderate Speed, Comprehensive
   /                \
  /------------------\   Micro Validation
 /                    \  (Format, Lint, Type Check)
/______________________\ Fast, Shallow, Frequent
```

The base of the pyramid (micro validation) runs constantly and catches simple errors. The top of the pyramid (team validation) runs rarely and catches complex errors.

Most errors should be caught at the base. If you find most errors in team validation, your micro and macro validation are insufficient.

The goal is to push error detection as far down the pyramid as possible. Fast, automated checks at the base catch most issues. Slow, expensive checks at the top catch the subtle issues that require architectural insight.

## Getting Started

Start with micro validation:

1. Identify the formatters and linters appropriate for your project
2. Add a PostToolUse hook that runs them after file writes
3. Test the hook by having an agent write a file
4. Adjust the hook based on agent feedback

Once micro validation works, add macro validation:

1. Identify structural requirements (tests must pass, build must succeed)
2. Add a Stop hook that runs these checks
3. Test by having an agent complete a task
4. Refine checks based on what catches real issues

Finally, add team validation if needed:

1. Create a validator agent with read-only permissions
2. Give it a clear review checklist
3. Invoke it manually after significant changes
4. Consider automating invocation via Stop hooks for critical features

Build the validation system incrementally. Start simple, add complexity as you learn what errors matter most in your workflow.

## Conclusion

Self-validating agents shift quality control from manual review to automated checks. PostToolUse hooks catch syntax and style errors immediately. Stop hooks ensure structural requirements are met before task completion. Validator agents provide independent architectural review.

The three tiers work together: micro validation catches simple errors fast, macro validation ensures completeness, and team validation provides deep insight.

The benefits compound over time. Agents learn from validation feedback and produce better code with less intervention. Projects with comprehensive validation have fewer bugs in production, cleaner codebases, and faster development cycles.

Self-validation is not automatic. It requires upfront configuration, validator selection, and ongoing maintenance. But for teams building with Claude Code agents, the investment pays off in reduced error rates and improved code quality.

Start with PostToolUse hooks. Add Stop hooks when you need structural guarantees. Use validator agents when architectural review matters. Build the validation system that matches your quality requirements and agent workflows.
