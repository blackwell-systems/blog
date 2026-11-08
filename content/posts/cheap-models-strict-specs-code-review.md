---
title: "Cheap Models, Strict Specs: Code Review and Fixes for Cents"
date: 2026-11-08
draft: true
tags: ["ai", "llm", "ai-agents", "code-review", "automated-fixes", "openrouter", "cost-optimization", "token-optimization", "json-schema", "structured-output", "testing", "git-worktree", "python", "claude", "mimo", "glm", "developer-tools", "open-source"]
categories: ["ai", "tools", "developer-tools"]
description: "Cheap models failed as free-roaming agents. Wrapped in a small pipeline with exact inputs, checkable outputs and gated claims, they review code and fix confirmed bugs for cents."
summary: "Handing routine code review and small fixes to cheap models failed when they ran as agents: about 50 calls and 7.7 million input tokens with nothing edited. The version that works shrinks each job, makes every output machine-checkable, and only sends a finding to a fixer once two model families agree. A three-area review cost about 30 cents, and MiMo v2.6 Pro fixed 5 of 5 confirmed bugs while declining a planted wrong claim. Claude Opus, on my Anthropic plan, now reads only the findings table and short diffs, and every change still passes the same checks before it merges."
---

I use Claude Opus as the lead engineer on many of my AI-assisted projects. It's a great collaborator, and it is also the most expensive thing in my workflow: every file it reads to review or fix code counts against my Anthropic plan's usage limits. So I tried handing the routine parts, code review and small fixes, to models that cost a fraction as much on OpenRouter, without lowering the bar for what gets merged. The first attempt failed. The version that works wraps them in a small build pipeline, and it now finds and fixes bugs for cents.

This post describes the whole thing so you can adopt it. The scripts are in a small standalone repo: [cheap-llm-review-fix](https://github.com/blackwell-systems/cheap-llm-review-fix) (Python 3.10+, standard library only, MIT).

## What didn't work: a cheap model as an agent

The obvious move is to give a cheap model the same job you'd give a strong one: "here's a bug, go fix it", inside an agent harness that can read files, run commands and edit. I tried GLM 5.3 Flash this way on seven bounded bugs. In 11 minutes it made about 50 calls, read files over and over (about 7.7 million input tokens), and edited nothing. I stopped it.

The cheap model was perfectly capable of writing the fixes, as it turned out. What it couldn't do well was the open-ended part: finding the right code, deciding it had seen enough, and committing to a change. (Later, Claude Haiku 5.5 did fine as an agent on a doc sweep: 15 calls, about 6 cents, 19 correct edits across 10 files. So it isn't that cheap models can't explore; the weakest ones can't, and even the good ones are most reliable when the job is bounded and checkable.)

## "Isn't this just a model router with extra steps?"

That was my first worry too. A router decides which model handles a request and hopes the answer is good. That's exactly what failed above: choosing a cheaper model doesn't help if it can't do the job in the shape it's asked.

The extra steps are what make it work:

1. **Shrink the job to fit the model.** No exploring. The model gets the exact function, the related code and the test file, and only has to write a few edits.
2. **Make every output machine-checkable.** Quoted code must exist in the file; named functions must be real and contain the quote; each edit must match exactly once; the tests must pass. Wrong answers fail cheaply and automatically, before a person (or an expensive model) ever reads them.
3. **Gate claims before work starts.** A finding goes to a fixer only if two models from different families agree, or the lead confirmed it.
4. **Keep the lead's part tiny.** The lead reads a short diff, not the code around it.

The routing part (which model does which job) is just a parameter. The value is turning fuzzy work ("review this", "fix that") into small, checkable jobs. The closer comparison is a build pipeline with quality control: cheap workers, strict specs, automatic inspection, and a human sign-off at the end.

## The pipeline

```
review (2 models, JSON) -> merge + automatic checks -> confirm -> fix batch (exact edits, tests, commit) -> lead reads diffs, merges once
```

### 1. Review: two reviewers, structured answers

Two reviewers from different model families read a whole subsystem. Mine are **MiMo v2.6 Pro** and **GLM 5.3 Flash**. In a trial on the same code, they found almost entirely different bugs, so two finds far more than one. For high-stakes code I add **GLM 5.3**.

Each reviewer answers in a JSON schema, not prose. A finding looks like this (an illustrative example):

```json
{
  "title": "Retry loop gives up one attempt early",
  "severity": "medium",
  "confidence": "high",
  "kind": "bug",
  "file": "client/http.py",
  "symbol": "Client.fetch_with_retry",
  "evidence": "for attempt in range(1, self.max_retries):",
  "situation": "With max_retries=3 the loop runs twice, so a request that would succeed on the third try fails.",
  "fix": "Iterate range(self.max_retries) so every allowed attempt runs. Test with a server that fails twice, then succeeds.",
  "test_file": "tests/test_client.py",
  "related": ["client/http.py:Client._backoff"]
}
```

The important fields:

- **`evidence`** is one to three lines copied exactly from the file. It's the anti-hallucination hook: a script checks it.
- **`symbol`** names the function, so the fix step can pull exactly that code.
- **`test_file`** and **`related`** make the finding fix-ready: no one has to rewrite it as a task.

`ask_model.py --json-schema review_schema.json` puts the schema in the prompt, streams the answer, parses it, validates it against the schema, and rejects anything that doesn't conform. Some providers can enforce the schema themselves (OpenRouter's strict `response_format`): DeepInfra does for MiMo; Z.ai rejects it for GLM, so it's opt-in.

Reviewer prompt basics: an independent senior reviewer for that area, a list of failure modes to look for, rank by impact, give the concrete situation, mark guesses as guesses, no style comments.

### 2. Merge and check automatically

`merge_reviews.py a.json b.json --out merged.md` groups findings from all reviewers by file and function and, for every finding:

- checks the **evidence** is really in the file (after whitespace normalisation): `ok`, `partial` or `NOT FOUND`, which usually means the model reconstructed or invented the code;
- finds the **symbol** (a simple parser for Python and GDScript, and brace matching for C-family languages) and reports its line range, `symbol not found`, or `evidence outside` (a finding filed under the wrong function).

The Markdown table puts agreement and problems side by side.

### 3. Confirm before fixing

Only confirmed findings go to a fixer: two models flagged the same function and both checks pass, or the lead checked the claim against the code. `merge_reviews.py --batch-out batch.json --confirm 3,5b` writes exactly those (groups two models agree on are included automatically; `--confirm` adds ones the lead verified).

Why it matters: reviewers are wrong about one claim in six, stated just as confidently as the right ones, and **a fixer told "there's a bug here" tends to believe it**. In my trial I planted a finding I knew was wrong. GLM 5.3 Flash "fixed" the working code, and when its first test failed, its retry wrote a test that passed for the needless change. Green tests don't prove a change was needed.

### 4. Check that each finding is a good task

A confirmed bug can still be a bad fix task, and that turned out to be the weakest link in the whole pipeline (more on this in the results). So before a batch runs, `check_findings.py` has a model look at each finding exactly as the fixer will see it and answer, again in a schema: does the code shown actually demonstrate the bug? Is code the fixer needs missing? Can the named test file test this at all (a unit test file has no scene or physics; behaviour that needs them belongs in a scenario test)? Is the suggested fix sound? Findings that aren't ready get repaired (a better test file, more related code) or dropped. It also catches some wrong claims on its own: when the code shown doesn't demonstrate the bug, that's often because there isn't one.

### 5. Fix in batches: exact edits, tests, commit

`fix_batch.py batch.json --worktree ../repo-fix --out-dir fixes/` runs each finding through `model_fix.py` (Claude Haiku 5.5 by default, see the results), which:

1. builds the context from the finding: the named function's lines, the `related` functions, the whole test file, and an outline of every file it shows part of (the class's declarations: members, constants, signatures) plus the test helpers, so the fixer knows the fields a function uses and the test API it must call;
2. tells the model to check the claim first and to answer with exact edits in `patch_schema.json`: a decision (`fix` or `not a bug`), a summary, and find/replace pairs where each `find` is whole lines copied from the file;
3. applies the edits only if **every** `find` matches exactly once (restoring tabs if the model wrote spaces), otherwise rejects the patch and writes nothing;
4. runs the finding's tests in a git worktree;
5. on any failure (bad JSON, an edit that doesn't match, a failing test) gives the model the problem, including the failing assertion lines, and one more try against the original code;
6. commits a passing fix in the worktree.

`fix_status.py fixes/` shows one line per fix while it runs:

```
trial-4: PASSED c147a9a (passed; 207 s, $0.01054)
trial-5: attempt 1: asking: 7 s, thinking 1700 chars, answer 0 chars
```

Use batches only. A single small fix is cheaper for the lead to just write; the savings come from many fixes and one review pass.

### 6. The lead reads every diff and merges once

Run the full test suite on the worktree, read each diff (they're small), drop anything that shouldn't be there, merge once.

## Results

**Reviews.** A review of three subsystems in one of my projects with MiMo v2.6 Pro, GLM 5.3 Flash and GLM 5.3 cost about **30 cents**. After I checked every claim, about 30 held up. One was a bug I had seen but hadn't tracked down; MiMo found the cause in the math behind it.

**Fixes.** Six findings in the review format: five real, confirmed bugs (one or two functions each) and one planted wrong claim. Same findings, same prompts, one run per model:

| Model | Real fixes passed | Planted wrong claim | Time per fix | Cost, all six |
|---|---|---|---|---|
| Claude Haiku 5.5 (Google Vertex) | 5 of 5 | declined, with the right reason | 13 to 24 s | about $0.010 |
| MiMo v2.6 Flash (DeepInfra) | 5 of 5 | declined, with the right reason | 41 s to 2.5 min | about $0.009 |
| Qwen 3.8 Flash (Alibaba) | 5 of 5 | declined, with the right reason | 1.5 to 2 min | about $0.032 |
| MiMo v2.6 Pro (DeepInfra) | 5 of 5 | declined, with the right reason | 1 to 3.5 min | about $0.034 |
| GLM 5.3 Flash (Z.ai) | 4 of 5 | "fixed" it | 10 to 30 s | about $0.012 |

Every passing diff I read was minimal and correct, with a real test. On a harder batch of six real fixes in the same codebase (geometry, a new validator check, a hang guard), MiMo v2.6 Flash passed all six for about 4 cents, and I merged its set after reading every diff. That review caught one thing the tests couldn't: the finding itself asked for a behaviour the original code had deliberately avoided, and both models followed the finding. A fixer is only as good as the finding it's given.

**How much to trust that.** Not much on its own: one run per model, five real fixes, a single planted wrong claim (an obvious one: a misread sign), and four perfect scores means the test was too easy to tell them apart. The code is GDScript, a niche language with far less training data than Python or TypeScript, which probably makes this harder than most codebases. So I built a proper benchmark.

### The fix benchmark

Twenty findings in the review format, shuffled: real bugs of mixed difficulty (including two hard ones: a multi-segment grind hand-off that half-committed its state, and facet checks that missed kinks between two collision shapes), a few latent ones (hardening against misuse that can't happen today), and wrong claims that real reviewers made earlier that day, each disproved against the code. An answer key the fixers never see says which is which. Each model runs the whole set three times, each run in a fresh worktree, and every diff is kept.

The first run measured me, not the models. Eight findings pointed at test files in the wrong folder and crashed before reaching a model; several pointed at unit test files for behaviour that needs a running scene; and fixers were shown a function without the class fields it uses. That's what produced the readiness check and the class outlines in steps 4 and 5: at first only 6 of the 14 real findings were ready; after the repairs, 11 were (the rest are the hardest ones, and the check rightly marks most of the planted wrong claims as not ready too).

Two more things the benchmark taught me about my own answer key:

- **Latent findings deserve their own column.** Haiku declined "the hanger height can go negative" with the reason that no gear combination allows it, and "the event counter can go below zero" as a caller error rather than a defect. Those are reasonable calls, not failures, so latent findings are scored apart from definite bugs.
- **The fixer caught my mistake.** One "real" bug was a reviewer's claim I had confirmed: that a take-off skipped a tick of air movement. Haiku refused it, explaining that the tick's travel had already happened, so the suggested fix would move the skater twice. It was right. That finding is now one of the fakes.

Claude Haiku 5.5, three runs:

| Run | Definite bugs fixed | Latent fixed | Wrong claims refused | Wrong claims "fixed" | Time | Cost |
|---|---|---|---|---|---|---|
| 1 | 6 of 9 (both hard ones) | 0 of 3 (declined, sensibly) | 7 of 7 | 0 | 6 min | $0.06 |
| 2 | 6 of 9 | 3 of 3 | 5 of 7 | 1 | 6.5 min | $0.06 |
| 3 | 7 of 9 | 1 of 3 | 6 of 7 | 1 | 6 min | $0.06 |

Its misses on real bugs were tests that didn't work (a scene test that never set up the situation, a test node left out of the scene tree, and a deadzone test fed through a helper that bypasses deadzones). The wrong claim it "fixed" both times was the same one: a 2 cm sideways offset on a decorative bolt that a reviewer called a typo, but that matches a real truck's bolt pattern. Claims with logic errors didn't fool it; a plausible misreading of a design choice did. That is exactly the failure the confirmation gate exists for.

I also started MiMo v2.6 Flash and Qwen 3.8 Flash on the same benchmark and stopped them part way through their first run. They fixed real bugs about as well, but they "fixed" far more of the wrong claims (2 of 5 and 4 of 6 so far, against Haiku's 0 to 2 of 7), and they were much too slow to work with: about two hours per 20-finding run, against Haiku's six minutes. Prices don't show that. These models think at length before every answer (often 25,000 to 90,000 characters of hidden reasoning for one small fix, whatever effort you ask for), and their providers generate tokens more slowly (published rates are about 35 tokens a second for MiMo Flash and 85 for Qwen, against about 230 for Haiku). On the six-finding trial they all looked equal; it took the bigger benchmark to separate them.

The benchmark paid for itself in code, too. Its runs wrote passing fixes for eleven items in my backlog (eight bugs, including both hard ones, and three hardening fixes). I read every diff, merged them, and the full suite passed: about 18 cents of model time for eleven fixes I didn't write.

## The irony: the best cheap fixer so far is Claude

The whole point was to spend less of my Anthropic plan. I went looking at models from Xiaomi, Zhipu and Alibaba, and the fastest fixer with a perfect score, at about a cent for six fixes, turned out to be Claude Haiku 5.5: Anthropic's own smallest model. So I'm paying Anthropic per token to avoid using my Anthropic subscription.

It's less backwards than it sounds. The plan covers my sessions with Opus, and what burns through it is reading: every file Opus opens to understand a bug. Haiku over OpenRouter (or Anthropic's API directly) is a separate pay-per-token bill. The reading moves off the plan, not off Anthropic.

The better irony is that Haiku was the model I'd banned. Earlier in this project I asked it for sourced physics research. It came back in two minutes with four paper citations: two DOIs that pointed to unrelated papers and two that didn't exist, despite its strong published scores on hallucination. I restricted it to chores and moved research to bigger models.

Same model, different shape of job. Given a finding, the exact function, the test file and a schema that only accepts edits matching the code exactly, it fixed all five real bugs, each in under 25 seconds. It also refused the planted wrong claim in 4 seconds, with the right reason. Open-ended work invites a model to fill gaps with something plausible. A job where every claim is checked against the code leaves it almost nowhere to do that. Which model you pick mattered less than how the job was shaped, and that's the whole argument of this post in one example. The benchmark kept it on top (and found its blind spot: a plausible misreading of a design choice), so it's now the default fixer.

(The lead that reads Haiku's diffs is Opus, so it's Claude checking Claude at the last step. The cross-family check sits earlier, where it matters: findings need two reviewers from different families to agree before any fixer sees them.)

**Prices** on OpenRouter as of November 2026, per million tokens, from providers that support structured output and don't collect data (check current prices; a model's headline price can come from a provider you can't use):

| Model | Input | Output | Notes |
|---|---|---|---|
| Claude Haiku 5.5 | $0.10 | $0.50 | Fastest fixer here; lowest published hallucination rate of these; pin a provider with structured output |
| MiMo v2.6 Flash | $0.14 | $0.28 | Best value: strong fixer for under a cent per fix |
| Qwen 3.8 Flash | $0.15 | $0.47 | Strong on coding benchmarks; served only by Alibaba |
| MiMo v2.6 Pro | $0.435 | $0.87 | A large model priced low; strong reviewer; slow |
| GLM 5.3 Flash | $0.15 | $0.50 | Genuinely small and fast; good second reviewer; easily led |
| GLM 5.3 | $1.40 | $4.40 | Strong third reviewer for high-stakes code; the priciest here |

## What it saves on my Anthropic plan, and what keeps the bar

Before, a review meant Opus reading every file in a subsystem, and a fix meant Opus reading the code around the bug, writing the change and iterating until the tests passed. All of that counted against my plan. Now the reading, reviewing, writing and test iterations run on OpenRouter for cents. Opus reads the merged findings table, checks the claims the two reviewers didn't agree on, and reads short diffs of fixes that already pass their tests. My plan's usage goes to the work that needs it: design, multi-file changes and judgment calls.

The quality bar stays where it was, because nothing reaches the merge without passing the checks a careful reviewer would apply, plus some no one applies by hand:

- the quoted evidence must exist in the file, and the named function must contain it;
- a finding needs agreement from two model families, or the lead's confirmation, before anything fixes it;
- every edit must match the file exactly once, or the whole patch is rejected;
- the finding's tests must pass in a worktree, and then the full suite;
- the lead reads every diff and decides what merges.

The planted wrong claim shows why the gate matters. In normal use, the confirmation step stops a claim like that before a fixer ever sees it. In the trial I sent it through on purpose: one fixer "fixed" working code, and the other four declined it.

## Lessons and gotchas

- **Cheap isn't the same as small.** MiMo v2.6 Pro is a large model with a low price; GLM 5.3 Flash is genuinely small. Both do badly as free-roaming agents and well on bounded jobs.
- **MiMo is slow regardless of effort.** Reviews take 10 to 20 minutes, even at low reasoning effort, because it writes 30k to 50k tokens, mostly hidden reasoning. Stream the response (a long silent call trips read timeouts), give it a large output limit (it once spent the whole limit thinking and returned nothing), and show progress: my tool counts the reasoning so a progress file reads "thinking 16128 chars" instead of an ominous "0 chars".
- **Send whole subsystems, not halves.** Splitting files across two calls to save time made each half report things it couldn't see.
- **Expect broken JSON and handle it.** I saw a reviewer echo the schema before its answer, quote marks left unescaped inside code strings, and an empty array left out. Pick the answer object out of the reply, repair stray quotes, use provider-enforced schemas where available, and keep one retry.
- **Retry feedback must show the failing assertion.** My first version sent the end of the test output, which was the slowest-tests list, so the model never learned which assertion failed.
- **Refuse providers that keep your code.** OpenRouter's `provider: {data_collection: "deny"}` does it per request.
- **The findings are the weak link, not the fixers.** Wrong test files, missing context and suggested fixes that can't be tested caused more failures than model mistakes. Check each finding as a task before running a batch.
- **Show the class, not just the function.** A fixer given one function guesses at the fields and helpers around it. An outline of the file's declarations is cheap and removes most of those guesses.
- **Run more than once.** The same model on the same findings changed its mind between runs: it declined the latent findings in one run and fixed them all in the next, and refused every wrong claim in one run and fell for one in the next two. One run is an anecdote.
- **It doesn't fit everything.** Design, multi-file changes and anything that needs judgment stay with the strong model. The pipeline is for the long tail of small, confirmed fixes, and there are always plenty of those.

## Try it

From your project's root, with the scripts cloned next to it:

```sh
git clone https://github.com/blackwell-systems/cheap-llm-review-fix ../cheap-llm-review-fix
T=../cheap-llm-review-fix
export OPENROUTER_API_KEY=sk-or-...    # or a macOS keychain item, service "openrouter"
mkdir -p reviews

# 1. Review a subsystem with two models from different families
python3 $T/ask_model.py --prompt-file $T/examples/review_prompt.md \
    --file src/cart.py --file src/pricing.py --file tests/test_cart.py \
    --json-schema $T/review_schema.json --strict-schema --effort low \
    --model xiaomi/mimo-v2.6-pro --provider deepinfra --out reviews/mimo.json
python3 $T/ask_model.py --prompt-file $T/examples/review_prompt.md \
    --file src/cart.py --file src/pricing.py --file tests/test_cart.py \
    --json-schema $T/review_schema.json --effort low \
    --model z-ai/glm-5.3-flash --provider z-ai --out reviews/glm.json

# 2. Merge, check, and write the batch (add --confirm 2,3b for findings you verified)
python3 $T/merge_reviews.py reviews/mimo.json reviews/glm.json --root . \
    --out reviews/merged.md --batch-out reviews/batch.json

# 3. Check each finding is a good fix task (fix or drop the ones that aren't ready)
python3 $T/check_findings.py reviews/batch.json --root . \
    --project-notes $T/examples/project_notes_python.md --out reviews/readiness.md

# 4. Fix the batch in a worktree (Claude Haiku 5.5 by default), watch it, then read the diffs
git worktree add -b review-fixes ../myproj-fixes
python3 $T/fix_batch.py reviews/batch.json --worktree ../myproj-fixes \
    --test-cmd "pytest {test_file}" --rules $T/examples/rules_python.md \
    --outline tests/helpers.py --out-dir reviews/fixes
python3 $T/fix_status.py reviews/fixes
git -C ../myproj-fixes log -p
```

The README covers every option. `examples/` has the reviewer prompt, rules and project-notes files for a Python and a Godot project, and a sample review; `fix_bench.py` and `docs/building-a-bench.md` cover building your own fix benchmark.

The specific models will be replaced within months. The approach carries over: give cheap models small jobs with exact inputs, make every output checkable, gate the claims, and keep the expensive attention for the last step.
