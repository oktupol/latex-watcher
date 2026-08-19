# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-purpose Docker image that watches a directory of `.tex` files and recompiles them to PDF on change — an offline replacement for Overleaf's live preview. The entire application is `watch.sh` (~50 lines of Alpine `ash`); everything else is packaging.

## Repository layout

- `watch.sh` — the whole program; container ENTRYPOINT
- `Dockerfile` — Alpine + `texlive-full` + `inotify-tools`, runs as unprivileged `watcher` user
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

Iterating on `watch.sh` alone is much faster by bind-mounting it over the copy in the image than by rebuilding (`texlive-full` is a very large layer):
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

`build_pdf` `cd`s into the source file's directory (so relative `\input`/`\includegraphics` resolve) and runs `pdflatex -interaction nonstopmode` with `-output-directory` pointing at the destination. It is a single pass — references and TOCs will be stale on first build.

In `WATCH_MODE=true`, `inotifywait --monitor` feeds a read loop; the `timeout 1 cat >/dev/null` line is a debounce that swallows the burst of events an editor save produces before re-running `collect_changes`.

## Conventions

- The script targets busybox `ash` under Alpine, not bash — keep constructs compatible with the image's shell.
- Directories come from `INPUT_CACHE_DIR`, `INPUT_SOURCE_DIR`, `INPUT_DESTINATION_DIR`, all set in the Dockerfile; `WATCH_MODE` is the only variable users are expected to set.
- Alpine and apk package versions in the Dockerfile are pinned exactly (`texlive-full=2025.2-r0`, `inotify-tools=4.23.9.0-r0`); a base-image bump usually requires updating those pins too, since old apk revisions disappear from the repos.
- Images publish on every push to `main` (as `:latest`) and on `v*` tags (tag `v1.1` → image `:1.1`). User-facing docs reference the numbered tag, so a release means: tag, then update the image tag in `README.md` and on the `example` branch.
