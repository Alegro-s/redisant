CREATE TABLE IF NOT EXISTS nexus_engine_policy (
    id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    manifest_url text,
    recommended_version text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO nexus_engine_policy (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;
