CREATE DATABASE IF NOT EXISTS default;

CREATE TABLE IF NOT EXISTS nexus_ingested_metrics (
  api_key_id String,
  user_id String,
  name String,
  value Float64,
  tags String,
  ts String
) ENGINE = MergeTree ORDER BY (user_id, ts);

CREATE TABLE IF NOT EXISTS nexus_ingested_logs (
  api_key_id String,
  user_id String,
  level String,
  message String,
  tags String,
  ts String
) ENGINE = MergeTree ORDER BY (user_id, ts);
