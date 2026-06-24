-- Lynx developer analytics (downloads, play sessions)
CREATE TABLE IF NOT EXISTS lynx_asset_downloads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_kind TEXT NOT NULL,
    asset_id TEXT NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lynx_asset_downloads_user_created
    ON lynx_asset_downloads (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lynx_asset_downloads_asset_created
    ON lynx_asset_downloads (asset_kind, asset_id, created_at DESC);

CREATE TABLE IF NOT EXISTS lynx_play_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES nexus_cloud_projects(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    duration_sec INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lynx_play_sessions_user_created
    ON lynx_play_sessions (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lynx_play_sessions_project_created
    ON lynx_play_sessions (project_id, created_at DESC);

-- Super-admin for Lynx ops (rozalityai@gmail.com)
UPDATE users
SET role = 'nexus', updated_at = NOW()
WHERE lower(trim(email)) = 'rozalityai@gmail.com'
  AND role IN ('user', 'admin');
