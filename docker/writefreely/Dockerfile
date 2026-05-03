ARG WRITEFREELY_VERSION=0.16.0
ARG GO_VERSION=1.25.9
ARG LESS_VERSION=4.6.4
ARG LESS_CLEAN_CSS_VERSION=1.6.0

FROM golang:${GO_VERSION}-alpine3.22 AS builder
ARG WRITEFREELY_VERSION
ARG LESS_VERSION
ARG LESS_CLEAN_CSS_VERSION
RUN apk add --no-cache ca-certificates curl make nodejs npm tar
WORKDIR /src/writefreely
RUN curl -fsSL \
    "https://github.com/writefreely/writefreely/archive/refs/tags/v${WRITEFREELY_VERSION}.tar.gz" \
    -o /tmp/writefreely-source.tar.gz \
    && tar -xzf /tmp/writefreely-source.tar.gz -C /src/writefreely --strip-components=1
RUN go build -v -o writefreely ./cmd/writefreely
RUN npm install -g "less@${LESS_VERSION}" "less-plugin-clean-css@${LESS_CLEAN_CSS_VERSION}" \
    && mkdir -p static/css
WORKDIR /src/writefreely/less
RUN lessc app.less --clean-css="--s1 --advanced" ../static/css/write.css \
    && lessc fonts.less --clean-css="--s1 --advanced" ../static/css/fonts.css \
    && lessc icons.less --clean-css="--s1 --advanced" ../static/css/icons.css \
    && lessc prose.less --clean-css="--s1 --advanced" ../static/css/prose.css
WORKDIR /src/writefreely/prose
RUN npm install \
    && NODE_OPTIONS=--openssl-legacy-provider npm run-script build
WORKDIR /src/writefreely
RUN rm -rf \
    less \
    prose/node_modules \
    prose/package.json \
    prose/package-lock.json \
    go.mod \
    go.sum

FROM alpine:3.23
RUN apk add --no-cache ca-certificates mysql-client tzdata

WORKDIR /opt/writefreely
COPY --from=builder /src/writefreely/ /opt/writefreely/
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
