-- Buckets привязаны к подпроекту (wm_baas_environments), как schema PostgreSQL.

ALTER TABLE wm_baas_buckets
    ADD COLUMN IF NOT EXISTS environment_id UUID REFERENCES wm_baas_environments(id) ON DELETE CASCADE;

UPDATE wm_baas_buckets b
SET environment_id = e.id
FROM wm_baas_environments e
WHERE e.user_id = b.user_id
  AND e.is_default = true
  AND b.environment_id IS NULL;

UPDATE wm_baas_buckets b
SET environment_id = (
    SELECT e.id
    FROM wm_baas_environments e
    WHERE e.user_id = b.user_id
    ORDER BY e.is_default DESC, e.created_at ASC
    LIMIT 1
)
WHERE b.environment_id IS NULL;

ALTER TABLE wm_baas_buckets
    ALTER COLUMN environment_id SET NOT NULL;

ALTER TABLE wm_baas_buckets DROP CONSTRAINT IF EXISTS wm_baas_buckets_user_id_name_key;

ALTER TABLE wm_baas_buckets
    ADD CONSTRAINT wm_baas_buckets_environment_id_name_key UNIQUE (environment_id, name);

CREATE INDEX IF NOT EXISTS idx_wm_baas_buckets_environment ON wm_baas_buckets (environment_id);
