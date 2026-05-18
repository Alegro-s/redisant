-- Waypoint Desktop: pairing, devices, refresh tokens

ALTER TABLE api_keys ADD COLUMN IF NOT EXISTS scope TEXT NOT NULL DEFAULT 'general';

CREATE TABLE IF NOT EXISTS desktop_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,
    host_label TEXT,
    os_info TEXT,
    sync_telemetry BOOLEAN NOT NULL DEFAULT true,
    sync_tasks BOOLEAN NOT NULL DEFAULT false,
    sync_projects BOOLEAN NOT NULL DEFAULT false,
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_desktop_devices_user ON desktop_devices(user_id) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS desktop_pairing_codes (
    code TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    claimed_device_id UUID REFERENCES desktop_devices(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_desktop_pairing_expires ON desktop_pairing_codes(expires_at);

CREATE TABLE IF NOT EXISTS auth_refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    device_id UUID REFERENCES desktop_devices(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_refresh_user ON auth_refresh_tokens(user_id) WHERE revoked_at IS NULL;
