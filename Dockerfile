FROM alpine:latest
RUN apk --update add mysql-client curl && rm -rf /var/cache/apk/*
COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
