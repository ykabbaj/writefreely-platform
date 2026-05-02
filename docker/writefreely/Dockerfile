ARG WRITEFREELY_VERSION=0.16.0

FROM alpine:3.20 AS downloader
ARG WRITEFREELY_VERSION
RUN apk add --no-cache ca-certificates curl tar
RUN curl -fsSL \
    "https://github.com/writefreely/writefreely/releases/download/v${WRITEFREELY_VERSION}/writefreely_${WRITEFREELY_VERSION}_linux_amd64.tar.gz" \
    -o /tmp/writefreely.tar.gz \
    && mkdir -p /opt \
    && tar -xzf /tmp/writefreely.tar.gz -C /opt

FROM alpine:3.20
RUN apk add --no-cache ca-certificates mariadb-client tzdata

WORKDIR /opt/writefreely
COPY --from=downloader /opt/writefreely/ /opt/writefreely/
COPY docker/writefreely/entrypoint.sh /usr/local/bin/writefreely-entrypoint

RUN chmod +x /usr/local/bin/writefreely-entrypoint \
    && ln -s /opt/writefreely/writefreely /usr/local/bin/writefreely \
    && addgroup -S writefreely \
    && adduser -S -G writefreely writefreely \
    && mkdir -p /data \
    && chown -R writefreely:writefreely /data /opt/writefreely

USER writefreely
EXPOSE 8080

ENTRYPOINT ["writefreely-entrypoint"]
CMD ["writefreely", "-c", "/data/config.ini"]
