FROM rust:1.43 AS builder

RUN USER=root cargo new --bin --name gw2-dps-report /build

WORKDIR /build

COPY Cargo.* ./

RUN cargo build --release && \
    rm src/*.rs

COPY src/ ./src/

RUN rm ./target/release/deps/gw2* && \
    cargo build --release

FROM alpine AS jq

ENV JQ_VERSION=1.6

RUN apk update && \
    apk add --no-cache \
        ca-certificates \
        curl && \
    curl -o /tmp/jq-linux64 -L https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 && \
    cp /tmp/jq-linux64 /bin/jq && \
    chmod +x /bin/jq && \
    rm -f /tmp/jq-linux64

FROM alpine AS parser

ARG ELITE_INSIGHTS_VERSION=2.28.0.0

RUN apk update && \
    apk add --no-cache \
        ca-certificates \
        curl \
        zip

WORKDIR /build

RUN curl -o ./GW2EI.zip -L https://github.com/baaron4/GW2-Elite-Insights-Parser/releases/download/v${ELITE_INSIGHTS_VERSION}/GW2EI.zip && \
    unzip ./GW2EI.zip && \
    rm -rf ./GW2EI.zip

FROM mono:5

ENV EVTC_PARSER_PATH=/bin/parser
ENV FILE_BASE_PATH=/files
ENV SERVER_FILE_PATH=/srv/gw2-dps-report
ENV SERVER_LISTEN_ADDR=0.0.0.0
ENV SERVER_LISTEN_PORT=80

LABEL org.opencontainers.image.authors "Yang Sheng Han <https://progamesigner.com>"
LABEL org.opencontainers.image.description "Upload arcdps logs and send to Discord automatically."
LABEL org.opencontainers.image.documentation "https://github.com/progamesigner/gw2-dps-report"
LABEL org.opencontainers.image.title "progamesigner/gw2-dps-report"
LABEL org.opencontainers.image.url "https://github.com/progamesigner/gw2-dps-report"
LABEL org.opencontainers.image.version "0.8.16"

WORKDIR /GW2EI

COPY --from=jq /bin/jq /bin/jq
COPY --from=parser /build /GW2EI
COPY --from=builder /build/target/release/gw2-dps-report /bin/gw2-dps-report
COPY --from=builder /build/target/release/clean /bin/gw2-dps-clean
COPY res/ /srv/gw2-dps-report/
COPY settings.conf /GW2EI/settings.conf
COPY parser.sh /bin/parser

VOLUME ["/files"]

EXPOSE 80

ENTRYPOINT ["/bin/gw2-dps-report"]
