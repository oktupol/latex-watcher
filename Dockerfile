FROM alpine:3.23.3

# Latex packages
RUN apk add texlive-full=2025.2-r0

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

VOLUME [ "/opt/watcher/cache", "/opt/watcher/source", "/opt/watcher/destination" ]

# Permissions
RUN chown -R watcher:watcher /home/watcher
RUN chown -R watcher:watcher $INPUT_CACHE_DIR
RUN chown -R watcher:watcher $INPUT_SOURCE_DIR
RUN chown -R watcher:watcher $INPUT_DESTINATION_DIR

USER watcher
WORKDIR /home/watcher

ENTRYPOINT [ "/home/watcher/watch.sh" ]
