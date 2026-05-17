CREATE TABLE IF NOT EXISTS platform_artifact_channel (
    slug TEXT PRIMARY KEY,
    manifest_url TEXT NOT NULL DEFAULT '',
    recommended_version TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE platform_artifact_channel IS 'Публичные манифесты по slug; пустой manifest_url → пустой список релизов';
