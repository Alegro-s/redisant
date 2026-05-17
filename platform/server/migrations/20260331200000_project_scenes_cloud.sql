CREATE TABLE IF NOT EXISTS project_scenes (
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    scene_id TEXT NOT NULL,
    content JSONB NOT NULL,
    revision BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    PRIMARY KEY (project_id, scene_id)
);

CREATE INDEX IF NOT EXISTS idx_project_scenes_project ON project_scenes (project_id);
