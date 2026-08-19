# TeX Live 2026. Pinned by digest because upstream publishes no per-year tag for
# the current release — `latest` is the only moving target, and TL#### tags only
# appear once a year goes historic. Bumping means re-resolving the digest:
#   docker buildx imagetools inspect texlive/texlive:latest
FROM texlive/texlive:latest@sha256:ee8ecc627897eabeb42d862d8187546483455e66ce94aa5c2bce1b45a977ab27

# Dependencies for watcher script
RUN apt-get update \
	&& apt-get install -y --no-install-recommends inotify-tools \
	&& rm -rf /var/lib/apt/lists/*

# watcher MUST be uid/gid 1000. Bind-mounted source/destination dirs come from
# the host and are typically owned by the first human user there (1000), which
# is what the Alpine-based images up to v2.1 also produced. The texlive base
# already parks a `texlive` user on 1000, so plain useradd lands on 1001 and
# pdflatex then fails with "I can't write on file ...log" for every document.
RUN userdel -r texlive \
	&& groupadd --gid 1000 watcher \
	&& useradd --uid 1000 --gid 1000 --create-home watcher

# Watcher script
COPY watch.sh /home/watcher/watch.sh
RUN chmod +x /home/watcher/watch.sh

# Volumes
ENV INPUT_CACHE_DIR="/opt/watcher/cache"
RUN mkdir -p $INPUT_CACHE_DIR

ENV INPUT_SOURCE_DIR="/opt/watcher/source"
RUN mkdir -p $INPUT_SOURCE_DIR

ENV INPUT_DESTINATION_DIR="/opt/watcher/destination"
RUN mkdir -p $INPUT_DESTINATION_DIR

# Permissions
RUN chown -R watcher:watcher /home/watcher
RUN chown -R watcher:watcher $INPUT_CACHE_DIR
RUN chown -R watcher:watcher $INPUT_SOURCE_DIR
RUN chown -R watcher:watcher $INPUT_DESTINATION_DIR

# Volumes must be declared AFTER the chowns: Docker discards changes made
# to a volume path in later layers, which would leave these dirs root-owned.
VOLUME [ "/opt/watcher/cache", "/opt/watcher/source", "/opt/watcher/destination" ]

USER watcher
WORKDIR /home/watcher

ENTRYPOINT [ "/home/watcher/watch.sh" ]
