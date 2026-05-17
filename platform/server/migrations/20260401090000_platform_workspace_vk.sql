ALTER TABLE admin_activation_keys ALTER COLUMN created_by DROP NOT NULL;

ALTER TABLE admin_activation_keys
  ADD COLUMN IF NOT EXISTS key_kind TEXT NOT NULL DEFAULT 'admin';
ALTER TABLE admin_activation_keys
  ADD COLUMN IF NOT EXISTS pool_generated BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE admin_activation_keys DROP CONSTRAINT IF EXISTS admin_activation_keys_key_kind_check;
ALTER TABLE admin_activation_keys
  ADD CONSTRAINT admin_activation_keys_key_kind_check CHECK (key_kind IN ('admin', 'nexus'));

UPDATE admin_activation_keys SET key_kind = 'admin' WHERE key_kind IS NULL OR key_kind = '';

CREATE TABLE IF NOT EXISTS user_workspace (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  db_mode TEXT CHECK (db_mode IN ('cloud', 'existing', 'none')),
  agent_api_key TEXT,
  connection_url TEXT,
  server_hosting BOOLEAN NOT NULL DEFAULT false,
  onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vk_web_module (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id_token TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  server_ip TEXT NOT NULL,
  selected_functions JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vk_web_user ON vk_web_module (user_id);

CREATE TABLE IF NOT EXISTS module_test_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  git_url TEXT,
  demo_mode TEXT,
  status TEXT NOT NULL DEFAULT 'queued',
  summary JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_module_test_user ON module_test_runs (user_id, created_at DESC);
