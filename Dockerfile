FROM alpine:3.24.1

# Latex packages
RUN apk add texlive-full=2026.0-r0

# Dependencies for watcher script
RUN apk add inotify-tools=4.23.9.0-r0

RUN adduser -D watcher

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
