
CREATE TABLE IF NOT EXISTS ai_usage_daily (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    persona TEXT NOT NULL CHECK (persona IN ('business', 'developer')),
    message_count INT NOT NULL DEFAULT 0 CHECK (message_count >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, usage_date, persona)
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_daily_user_date ON ai_usage_daily (user_id, usage_date DESC);

CREATE TABLE IF NOT EXISTS waypoint_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    campaign TEXT NOT NULL DEFAULT '',
    redeem_limit INT NOT NULL DEFAULT 0,
    redeemed INT NOT NULL DEFAULT 0 CHECK (redeemed >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT waypoint_vouchers_user_code UNIQUE (user_id, code),
    CONSTRAINT waypoint_vouchers_limit_nonneg CHECK (redeem_limit >= 0)
);

CREATE INDEX IF NOT EXISTS idx_waypoint_vouchers_user ON waypoint_vouchers (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS waypoint_shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_ref TEXT NOT NULL DEFAULT '',
    route TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'draft',
    carrier TEXT NOT NULL DEFAULT '',
    meta JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_waypoint_shipments_user ON waypoint_shipments (user_id, created_at DESC);
