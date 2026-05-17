CREATE TABLE login_otp_challenges (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    channel TEXT NOT NULL CHECK (channel IN ('email', 'sms', 'nexus')),
    code_hash TEXT NOT NULL,
    nexus_code_plain TEXT,
    session_token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_login_otp_user_created ON login_otp_challenges (user_id, created_at DESC);
CREATE INDEX idx_login_otp_expires ON login_otp_challenges (expires_at) WHERE NOT consumed;
