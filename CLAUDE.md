# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-purpose Docker image that watches a directory of `.tex` files and recompiles them to PDF on change — an offline replacement for Overleaf's live preview. The entire application is `watch.sh` (~50 lines of POSIX `sh`); everything else is packaging.

## Repository layout

- `watch.sh` — the whole program; container ENTRYPOINT
- `Dockerfile` — `texlive/texlive` (Debian) + `inotify-tools`, runs as unprivileged `watcher` user
- `.github/workflows/publish.yml` — builds and pushes multi-arch images to `ghcr.io/<owner>/latex-watcher`
- `example` branch — holds the user-facing scaffold (`source/`, `destination/`, `docker-compose.yaml`) that the README tells users to clone. It is **not** a normal feature branch; keep the compose file's image tag in sync with the README when releasing.

## Build / run / test

There is no test suite, linter, or build system beyond Docker.

```sh
docker build -t latex-watcher .

# One-shot compile of ./source into ./destination
docker run --rm \
  -v "$PWD/source:/opt/watcher/source" \
  -v "$PWD/destination:/opt/watcher/destination" \
  -v latexwatcher-cache:/opt/watcher/cache \
  latex-watcher

# Continuous watch mode
docker run --rm -e WATCH_MODE=true ... latex-watcher
```

Iterating on `watch.sh` alone is much faster by bind-mounting it over the copy in the image than by rebuilding (the TeX Live base is a very large layer):
`-v "$PWD/watch.sh:/home/watcher/watch.sh:ro"`.

## How the change detection works

The cache directory is the state store, and its encoding is inverted from what you'd expect: **each cache file is *named* after the sha256 of a source file, and its *contents* are that source file's absolute path.**

`collect_changes` runs two passes:
1. Iterate existing cache entries. If the recorded path no longer exists → the file was deleted or moved, drop the entry (no rebuild). If the hash differs → rename the cache file to the new hash and rebuild.
2. Iterate `*.tex` under the source dir. Any file whose hash has no cache entry is new → create the entry and build.

Consequences worth knowing before changing this:
- A *moved* file is seen as delete + add, so it rebuilds via pass 2.
- Two identical `.tex` files collide on one cache entry — only one is tracked.
- Only `.tex` files are ever added to the cache, so edits to `.bib`, `.sty` or included images do not trigger a rebuild.
- The cache volume must persist across runs or everything rebuilds; conversely, wiping it is the way to force a full rebuild.
- Both loops iterate `find ... | while IFS= read -r`, not `for x in $(find ...)`. The latter word-splits, which silently skipped any path containing a space (fixed in v2.1). Paths containing *newlines* are still unsupported — POSIX `read` has no `-d`, so `find -print0` cannot be consumed.

`build_pdf` is a subshell function (`build_pdf() ( ... )`) so its `cd` into the source file's directory — needed for relative `\input`/`\includegraphics` to resolve — cannot leak into the caller. It runs `pdflatex -interaction nonstopmode` with `-output-directory` pointing at the destination, then reruns while the log reports `Rerun to get` / `Rerun LaTeX`, capped at two extra passes.

That rerun is what makes `\ref`, `\pageref` and the TOC correct on a document's *first* build. It is conditional, so once `.aux` is current the check costs one `grep`. Note `-output-directory` also puts `.aux`/`.toc` in the destination, and TeX Live finds them there again on the next run via `TEXMFOUTPUT` — so a stale `.aux` from a since-edited document can yield wrong-but-plausible numbers rather than an obvious `??`. Citations are a separate matter: `bibtex`/`biber` are never invoked, so `\cite` never resolves.

In `WATCH_MODE=true`, `inotifywait --monitor` feeds a read loop; the `timeout 1 cat >/dev/null` line is a debounce that swallows the burst of events an editor save produces before re-running `collect_changes`.

## Conventions

- The script targets POSIX `sh` (`#!/bin/sh`, Debian `dash` in the current base, busybox `ash` before v2.2) — not bash. Keep constructs portable: **no `[[ ]]`**, which busybox misparsed rather than rejected, so conditionals using it silently took the wrong branch (this is what broke `Changed:`/`Removed:` before v2.0). Use `[ ]` with `=`, and quote the operands.
- Directories come from `INPUT_CACHE_DIR`, `INPUT_SOURCE_DIR`, `INPUT_DESTINATION_DIR`, all set in the Dockerfile; `WATCH_MODE` is the only variable users are expected to set.
- The base is pinned by **digest**, not tag: upstream publishes no per-year tag for the current TeX Live release (`TL####` tags only appear once a year goes historic), so `latest` is the only moving reference. Re-resolve with `docker buildx imagetools inspect texlive/texlive:latest` when bumping.
- The base was Alpine + apk `texlive-full` up to v2.1. That was abandoned in v2.2 because **no Alpine release ships TeX Live 2026** — apk's `texlive-full=2026.0-r0` is a packaging number, not the TeX Live year, and both 3.24.1 and edge resolve it to TeX Live 2025. That left the image a year behind consumers building on `texlive/texlive`, with divergent package versions: moderncv 2.5.1 there loads `fontawesome5`, TL2026's loads `fontawesome6`, so icon macros like `\faCakeCandles` existed in one and not the other. Do not go back to Alpine to save image size without checking that TeX Live year first.
- **`VOLUME` must come after the `chown` lines** in the Dockerfile. Docker discards changes made to a volume path in later layers, so declaring it early leaves the directories root-owned and the cache volume unwritable — which silently disables change detection entirely (fixed in v2.0).
- Images publish on every push to `main` (as `:latest`) and on `v*` tags (tag `v2.2` → image `:2.2`). A multi-arch run takes ~45 min. Platforms are **amd64 and arm64 only** — `linux/arm/v7` was dropped in v2.2 because `texlive/texlive` does not publish it. User-facing docs reference the numbered tag, so a release means: tag, then update the image tag in `README.md` and on the `example` branch.
