FROM rust:1.31 AS server

RUN USER=root cargo new --bin --name server /build

WORKDIR /build

COPY server/Cargo.lock Cargo.lock
COPY server/Cargo.toml Cargo.toml

RUN cargo build --release && \
    rm src/*.rs

COPY server/ /build/

RUN rm target/release/deps/server* && \
    cargo build --release

FROM alpine AS jq

ENV JQ_VERSION=1.5

RUN apk update && \
    apk add --no-cache \
        ca-certificates \
        curl && \
    curl -o /tmp/jq-linux64 -L https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 && \
    cp /tmp/jq-linux64 /bin/jq && \
    chmod +x /bin/jq && \
    rm -f /tmp/jq-linux64

FROM alpine AS parser

ARG ELITE_INSIGHTS_VERSION=2.1.0.0

RUN apk update && \
    apk add --no-cache \
        ca-certificates \
        curl \
        zip

WORKDIR /build

RUN curl -o /build/GW2EI.zip -L https://github.com/baaron4/GW2-Elite-Insights-Parser/releases/download/v${ELITE_INSIGHTS_VERSION}/GW2EI.zip && \
    unzip /build/GW2EI.zip && \
    rm -rf /build/GW2EI.zip

FROM mono:5

ENV EVTC_PARSER_PATH=/bin/parser
ENV FILE_BASE_PATH=/files
ENV SERVER_FILE_PATH=/srv/server
ENV SERVER_LISTEN_ADDR=0.0.0.0
ENV SERVER_LISTEN_PORT=80

WORKDIR /GW2EI

COPY --from=jq /bin/jq /bin/jq
COPY --from=parser /build /GW2EI
COPY --from=server /build/target/release/server /bin/server
COPY --from=server /build/res/ /srv/server/
COPY settings.conf /GW2EI/settings.conf
COPY parser.sh /bin/parser

VOLUME ["/files"]

EXPOSE 80

ENTRYPOINT ["/bin/server"]
