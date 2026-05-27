---
title: "14,000 Python Developers Installed My Go Binary via pip. Here's How."
date: 2026-05-27
draft: false
tags: ["go", "python", "npm", "pypi", "distribution", "goreleaser", "cli", "devtools", "open-source", "cross-platform", "packaging", "wheel", "binary-distribution", "pip-install", "golang", "setuptools"]
categories: ["go", "tools", "open-source"]
description: "How to distribute a Go binary on PyPI and npm so Python and Node developers can install it with pip/npx. Platform-specific wheels, optionalDependencies, and a one-tag release pipeline. 12x download multiplier from distribution alone."
summary: "Your Go CLI tool is on GitHub Releases. 80% of developers will never find it there. Here's how to put it on pip and npm with 50 lines of bash, getting a 12x download multiplier. Full technique with scripts, numbers, and the release pipeline that ties it together."
---

![Go gopher in a snake costume among pythons](/images/gopher-snake-crawling.png)

Your Go binary is on GitHub Releases. Congratulations. Go developers will find it with `go install`. Everyone else won't.

Python developers search PyPI. Node developers search npm. They don't browse GitHub Releases pages. If your tool isn't where they look, it doesn't exist to them.

I put a Go binary on PyPI. It gets 14,234 downloads. The same binary on GitHub Releases: 2,111. A **12x multiplier** from distribution alone.

Here's the entire technique.

## The Numbers

| Channel | Downloads |
|---------|----------:|
| pip (mcp-assert) | 14,234 |
| pip (pytest plugin) | 5,285 |
| npm CLI | 1,862 |
| npm vitest/jest/bun plugins | 2,865 |
| GitHub Releases | 2,111 |
| Docker | 306 |
| **Total** | **25,663** |

GitHub Releases alone: 2,111. Adding pip and npm: 25,663. Same binary. Same tool. Different shelf.

## PyPI: Go Binary in a Python Wheel

A Python wheel is just a zip file with metadata. It doesn't have to contain Python code. It can contain a binary and a 36-line script that runs it.

### The Python "package" (36 lines)

```python
# mcp_assert/__main__.py

import os
import sys
import subprocess


def _find_binary():
    pkg_dir = os.path.dirname(os.path.abspath(__file__))
    names = ["mcp-assert.exe", "mcp-assert"] if sys.platform == "win32" else ["mcp-assert"]
    for name in names:
        path = os.path.join(pkg_dir, "bin", name)
        if os.path.isfile(path):
            return path
    return None


def main():
    binary = _find_binary()
    if binary is None:
        print(
            "mcp-assert: binary not found. This platform may not be supported.\n"
            "Install from https://github.com/blackwell-systems/mcp-assert/releases",
            file=sys.stderr,
        )
        sys.exit(1)

    result = subprocess.run([binary] + sys.argv[1:])
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
```

That's it. Locate the binary. Run it. Pass through args. Exit with its code.

### The pyproject.toml

```toml
[build-system]
requires = ["setuptools>=68.0"]
build-backend = "setuptools.build_meta"

[project]
name = "mcp-assert"
version = "0.2.0"
description = "Deterministic correctness testing for MCP servers"
requires-python = ">=3.8"

[project.scripts]
mcp-assert = "mcp_assert.__main__:main"

[tool.setuptools.package-data]
mcp_assert = ["bin/*"]
```

The `[project.scripts]` entry means `pip install mcp-assert` creates a `mcp-assert` command that calls your `main()` function. The user types `mcp-assert` in their terminal and gets your Go binary.

### Building platform-specific wheels

This is the key trick. You build one wheel per platform, each containing the correct binary:

```bash
# Platform mapping: goreleaser_key -> "pypi_platform_tag:binary_name:archive_ext"
declare -A PLATFORMS=(
  ["darwin_arm64"]="macosx_11_0_arm64:mcp-assert:tar.gz"
  ["darwin_amd64"]="macosx_10_12_x86_64:mcp-assert:tar.gz"
  ["linux_arm64"]="manylinux2014_aarch64:mcp-assert:tar.gz"
  ["linux_amd64"]="manylinux2014_x86_64:mcp-assert:tar.gz"
  ["windows_amd64"]="win_amd64:mcp-assert.exe:zip"
  ["windows_arm64"]="win_arm64:mcp-assert.exe:zip"
)

for GOKEY in "${!PLATFORMS[@]}"; do
  IFS=: read -r PLAT_TAG BINARY_NAME ARCHIVE_EXT <<< "${PLATFORMS[$GOKEY]}"

  # Download the binary from GitHub Releases
  curl -fsSL "https://github.com/${REPO}/releases/download/${TAG}/${ARCHIVE}" \
    -o "${TMP_DIR}/${ARCHIVE}"

  # Extract binary into the package
  mkdir -p "${PYPI_DIR}/mcp_assert/bin"
  # ... extract based on archive type ...
  
  # Build a wheel with the correct platform tag
  python3 -m wheel pack "${PYPI_DIR}" \
    --dest-dir "$DIST_DIR" \
    --build-tag "${PLAT_TAG}"
done
```

Each wheel is tagged with its platform (`macosx_11_0_arm64`, `manylinux2014_x86_64`, etc.). When a user runs `pip install mcp-assert`, pip downloads only the wheel matching their platform. They get a native binary without knowing it's not Python.

### Upload

```bash
python3 -m twine upload dist/*.whl
```

Six wheels go up. pip handles the rest.

## npm: Platform-Specific optionalDependencies

npm has a different mechanism but the same result.

### The parent package

```json
{
  "name": "@blackwell-systems/mcp-assert",
  "version": "0.2.0",
  "bin": {
    "mcp-assert": "bin/mcp-assert"
  },
  "optionalDependencies": {
    "@blackwell-systems/mcp-assert-darwin-arm64": "0.2.0",
    "@blackwell-systems/mcp-assert-darwin-x64": "0.2.0",
    "@blackwell-systems/mcp-assert-linux-arm64": "0.2.0",
    "@blackwell-systems/mcp-assert-linux-x64": "0.2.0",
    "@blackwell-systems/mcp-assert-win32-x64": "0.2.0",
    "@blackwell-systems/mcp-assert-win32-arm64": "0.2.0"
  }
}
```

### Each platform package

```json
{
  "name": "@blackwell-systems/mcp-assert-darwin-arm64",
  "version": "0.2.0",
  "os": ["darwin"],
  "cpu": ["arm64"],
  "files": ["bin/"]
}
```

The `os` and `cpu` fields tell npm to only install this package on matching systems. The user runs `npm install -g @blackwell-systems/mcp-assert` and gets only the binary for their platform.

## The Release Pipeline

One git tag triggers everything:

```
git tag v0.2.0 && git push --tags
```

That fires a GitHub Actions workflow that:

1. **GoReleaser** builds binaries for 6 platforms, creates GitHub Release
2. **pypi-publish job** downloads binaries, builds 6 wheels, uploads to PyPI
3. **npm-publish job** copies binaries into platform packages, publishes to npm
4. **winget job** submits manifest to microsoft/winget-pkgs
5. **snap job** builds and publishes to Snap Store
6. **homebrew job** updates the tap formula

Zero manual steps. Tag, push, walk away. Every package manager gets the new version.

## Why This Works

Go compiles to a static binary. No runtime dependency. No interpreter. No virtual environment. The binary IS the distribution. You're just putting it on a shelf where people already shop.

Python developers don't care that `mcp-assert` is written in Go. They care that `pip install mcp-assert` gives them a working `mcp-assert` command. The implementation language is invisible.

## The 12x Multiplier

If your Go tool is only on GitHub Releases:
- Go developers find it (go install)
- Everyone else doesn't

If your Go tool is on pip + npm + Homebrew + winget + Docker + GitHub Releases:
- Go developers find it
- Python developers find it
- Node developers find it
- macOS users find it
- Windows users find it
- CI/CD pipelines find it

Same tool. Same binary. 12x the reach.

## Scripts

The full implementation (50 lines of bash for PyPI, 30 for npm):

- [pypi-build-wheels.sh](https://github.com/blackwell-systems/mcp-assert/blob/main/scripts/pypi-build-wheels.sh)
- [pypi-publish.sh](https://github.com/blackwell-systems/mcp-assert/blob/main/scripts/pypi-publish.sh)
- [npm-publish.sh](https://github.com/blackwell-systems/mcp-assert/blob/main/scripts/npm-publish.sh)
- [release.yml workflow](https://github.com/blackwell-systems/mcp-assert/blob/main/.github/workflows/release.yml)

The tool this powers: [mcp-assert](https://github.com/blackwell-systems/mcp-assert) (deterministic testing for MCP servers). The technique works for any Go binary.

---

MIT license. Open source. Steal the scripts.
