
CREATE TABLE IF NOT EXISTS nexus_cloud_build_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES nexus_cloud_projects(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
    ref_name TEXT,
    label TEXT,
    log_excerpt TEXT,
    meta JSONB NOT NULL DEFAULT '{}'::jsonb,
    bullmq_job_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_nexus_cloud_build_jobs_project ON nexus_cloud_build_jobs(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nexus_cloud_build_jobs_owner ON nexus_cloud_build_jobs(owner_id, created_at DESC);

ALTER TABLE billing_accounts ADD COLUMN IF NOT EXISTS yookassa_customer_id TEXT;
