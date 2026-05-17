ALTER TABLE users
    ADD COLUMN IF NOT EXISTS e2ee_public_key TEXT,
    ADD COLUMN IF NOT EXISTS e2ee_key_updated_at TIMESTAMPTZ;

ALTER TABLE chat_messages
    ALTER COLUMN body DROP NOT NULL;

ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS e2ee_algorithm TEXT,
    ADD COLUMN IF NOT EXISTS e2ee_nonce TEXT,
    ADD COLUMN IF NOT EXISTS e2ee_ciphertext TEXT,
    ADD COLUMN IF NOT EXISTS e2ee_sender_key TEXT;

CREATE INDEX IF NOT EXISTS idx_users_e2ee_key ON users(id) WHERE e2ee_public_key IS NOT NULL;
