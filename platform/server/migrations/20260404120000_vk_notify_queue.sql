CREATE TABLE IF NOT EXISTS vk_notify_queue (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title text NOT NULL,
    body text NOT NULL,
    attempts int NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vk_notify_queue_due ON vk_notify_queue (next_attempt_at)
    WHERE attempts < 8;

CREATE TABLE IF NOT EXISTS vk_notify_dead (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    attempts int NOT NULL,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now()
);
