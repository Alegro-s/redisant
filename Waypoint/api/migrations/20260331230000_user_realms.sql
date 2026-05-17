CREATE TABLE user_realm (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    realm VARCHAR(32) NOT NULL CHECK (realm IN ('nexus', 'metric')),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, realm)
);

CREATE INDEX idx_user_realm_realm ON user_realm (realm);

INSERT INTO user_realm (user_id, realm)
SELECT u.id, r.realm
FROM users u
CROSS JOIN (VALUES ('nexus'), ('metric')) AS r (realm)
ON CONFLICT DO NOTHING;
