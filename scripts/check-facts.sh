#!/usr/bin/env bash
# Drift detector: flags known-stale figures across every public surface.
# Canonical values live in blog/data/facts.toml. Run before deploy.
set -uo pipefail
BASE="${BASE:-/Users/dayna/code}"
SURFACES=(
  "$BASE/blog/content"
  "$BASE/blog/layouts"
  "$BASE/blackwell-website/src"
  "$BASE/blackwell-systems/README.md"
)
# "stale-pattern|canonical reminder"
STALE=(
  "60,000+ monthly|downloads = 150K+"
  "35,000+ monthly|downloads = 150K+"
  "30K+ monthly|downloads = 150K+"
  "[Ss]ix language implementations|GCF implementations = 7 (incl .NET)"
  "33 merged PRs|PRs = 40+"
  "32 PRs merged|PRs = 40+"
  "2,400+ eval|GCF evals = 2,500+"
  "2%2C400%2B|GCF evals badge = 2,500+"
  "25+ open source|OSS projects = 20+"
  "4 published research|papers = 9 self-published"
  "9 published papers|papers should read 'self-published'"
  "9 published research papers|papers should read 'self-published'"
  "CNCF \\(gRPC error code fix\\)|etcd must be annotated '(in review)', not claimed as merged"
  "CI standard (at|by) Ant Group|antvis CI PR #294 was closed unmerged; say '9 crashes found, fixed upstream'"
  "integrated into CI within 3 days|antvis CI PR #294 was closed unmerged"
  "Adopted by 32 projects|GCF = 28 projects outside Blackwell Systems"
  "25\\+ (MCP server )?repos|WYRE = 39 MCP server repos"
  "28,000\\+ (total )?downloads|mcp-assert downloads = 55,000+"
  "#6 (all-time )?contributor|mcp-go rank = top-10 (No. 8 as of 2026-10-19)"
  "No\\. 6 all-time contributor|mcp-go rank = top-10"
  "Reindeer AI|no longer confirmed as an emulator user"
)
found=0
for e in "${STALE[@]}"; do
  pat="${e%%|*}"; msg="${e##*|}"
  hits=$(grep -rInE -- "$pat" "${SURFACES[@]}" 2>/dev/null | grep -v '/posts/')
  if [ -n "$hits" ]; then
    echo "✗ STALE: /$pat/   → $msg"
    echo "$hits" | sed 's/^/    /'
    found=1
  fi
done
if [ $found -eq 0 ]; then
  echo "✓ no known-stale figures on identity surfaces (canonical: blog/data/facts.toml)"
fi
exit $found
