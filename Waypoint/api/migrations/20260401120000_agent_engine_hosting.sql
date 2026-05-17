ALTER TABLE user_workspace
  ADD COLUMN IF NOT EXISTS agent_schema_snapshot JSONB,
  ADD COLUMN IF NOT EXISTS agent_last_seen TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS engine_download_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  aes_key BYTEA NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engine_dl_user ON engine_download_tokens (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS hosting_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'processing', 'done', 'cancelled')),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hosting_user ON hosting_requests (user_id, created_at DESC);
