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
