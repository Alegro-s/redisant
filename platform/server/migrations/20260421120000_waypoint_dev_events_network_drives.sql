
CREATE TABLE IF NOT EXISTS waypoint_dev_events (
    id BIGSERIAL PRIMARY KEY,
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    channel TEXT NOT NULL,
    event_name TEXT NOT NULL,
    value DOUBLE PRECISION,
    properties JSONB,
    "timestamp" TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_waypoint_dev_events_api_ts ON waypoint_dev_events(api_key_id, "timestamp" DESC);
CREATE INDEX IF NOT EXISTS idx_waypoint_dev_events_channel ON waypoint_dev_events(api_key_id, channel, "timestamp" DESC);

CREATE TABLE IF NOT EXISTS waypoint_network_drives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    protocol TEXT NOT NULL,
    endpoint_uri TEXT NOT NULL,
    path_prefix TEXT NOT NULL DEFAULT '',
    meta JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_waypoint_network_drives_owner ON waypoint_network_drives(owner_id, created_at DESC);
