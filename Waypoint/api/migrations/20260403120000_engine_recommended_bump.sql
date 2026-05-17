UPDATE nexus_engine_policy
SET recommended_version = '1.1.0',
    updated_at = now()
WHERE id = 1;
