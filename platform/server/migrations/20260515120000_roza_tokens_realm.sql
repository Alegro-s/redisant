-- Roza AI: отдельный realm и дневной учёт токенов
ALTER TABLE user_realm DROP CONSTRAINT IF EXISTS user_realm_realm_check;
ALTER TABLE user_realm ADD CONSTRAINT user_realm_realm_check CHECK (realm IN ('nexus', 'metric', 'roza'));

CREATE TABLE IF NOT EXISTS roza_token_daily (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL DEFAULT (timezone('utc', now()))::date,
    tokens_used INT NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, usage_date)
);

CREATE INDEX IF NOT EXISTS idx_roza_token_daily_date ON roza_token_daily (usage_date);

INSERT INTO user_realm (user_id, realm)
SELECT u.id, 'roza'
FROM users u
ON CONFLICT DO NOTHING;
