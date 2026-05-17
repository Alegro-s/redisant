# Продакшен-образ HTTP-агента (TLS терминирует reverse proxy, не этот контейнер).
# Сборка: docker build -t nexus-agent:local -f integrations/agent/Dockerfile integrations/agent

FROM rust:1.85-bookworm AS build
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/target/release/nexus-agent /usr/local/bin/nexus-agent
ENV RUST_LOG=info
EXPOSE 9847
USER nobody
ENTRYPOINT ["/usr/local/bin/nexus-agent"]
