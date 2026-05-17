# PO platform server — build: docker build --build-arg PO_BIN=waypoint-api -t waypoint-api .
FROM rust:1-bookworm AS builder
ARG PO_BIN=waypoint-api
WORKDIR /app
COPY Cargo.toml ./
COPY migrations ./migrations
COPY openapi.json swagger-ui.html ./
COPY src ./src
RUN cargo build --release --bin "${PO_BIN}"

FROM debian:bookworm-slim
ARG PO_BIN=waypoint-api
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 docker.io \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN mkdir -p /app/uploads/module-tests
COPY --from=builder /app/target/release/${PO_BIN} /usr/local/bin/po-api
EXPOSE 8080
ENV PO_SERVICE=waypoint
CMD ["po-api"]
