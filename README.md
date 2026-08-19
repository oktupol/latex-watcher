# LaTeX Watcher

## Motivation

[Overleaf](https://www.overleaf.com/) is pretty neat with its live updates upon
every keystroke, yet I am still uncomfortable with hosting my most important
documents on a free online service. I want the convenience of editing in
overleaf, but with the privacy that you can only get off-line.

## Prerequisites

Following software must be installed:

- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Set-Up

### Using Git

Execute following command to create the necessary project directory structure
and `docker-compose.yaml`:

```sh
git clone --depth 1 --branch example https://github.com/oktupol/latex-watcher.git
```

### Manual

Create following directory structure:

```
* [project root]
|
+-- source
|
+-- destination
```

In the project root directory, create a `docker-compose.yaml`:

```yaml
version: "3.8"
services:
  watcher:
    image: ghcr.io/oktupol/latex-watcher:2.0
    environment:
      WATCH_MODE: "true"
    volumes:
      - ./source:/opt/watcher/source
      - ./destination:/opt/watcher/destination
      - cache:/opt/watcher/cache
volumes:
  cache:
    driver: local
```

## Usage

Start the watcher using the command:

```sh
docker compose up
```

It now monitors all changes inside the `source` directory. Once it detects a
change, it will compile it and place the generated PDF in the `destination`
directory. You can now edit your `.tex` files using your favourite editor and
open a PDF-viewer to see the changes immediately whenever you save your
progress.

## Optional configuration

Following environment variables exist and can be overridden in
`docker-compose.yaml`:

- **WATCH_MODE** - Possible values:
    - `true` - the watcher continuously monitors the `source` directory until it
      is manually stopped.
    - `false` - the watcher checks for updates in the `source` directory once,
      builds the PDF files for changed tex files, then exits.
