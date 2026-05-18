-- Изолированные БД (подпроекты) на пользователя: отдельная schema PostgreSQL на окружение.

CREATE TABLE IF NOT EXISTS wm_baas_environments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    schema_name TEXT NOT NULL UNIQUE,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_wm_baas_environments_user ON wm_baas_environments (user_id, created_at DESC);

-- Перенос существующих схем пользователей в окружение «Основной».
INSERT INTO wm_baas_environments (user_id, name, slug, schema_name, is_default)
SELECT s.user_id, 'Основной', 'default', s.schema_name, true
FROM wm_baas_user_schema s
WHERE NOT EXISTS (
    SELECT 1 FROM wm_baas_environments e WHERE e.user_id = s.user_id AND e.is_default = true
);
