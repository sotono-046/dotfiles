CREATE TABLE IF NOT EXISTS comments (
 id TEXT PRIMARY KEY, project_id TEXT NOT NULL, target_type TEXT NOT NULL,
 target_id TEXT NOT NULL, author TEXT NOT NULL, body TEXT NOT NULL,
 created_at TEXT NOT NULL, done_reason TEXT, done_at TEXT,
 CHECK ((done_reason IS NULL AND done_at IS NULL) OR (length(trim(done_reason)) > 0 AND done_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS comments_target ON comments(project_id,target_type,target_id,created_at);
CREATE TABLE IF NOT EXISTS targets (
 project_id TEXT NOT NULL, id TEXT NOT NULL, page_path TEXT NOT NULL,
 selector TEXT NOT NULL, text_hint TEXT NOT NULL, revision TEXT NOT NULL,
 created_at TEXT NOT NULL, PRIMARY KEY(project_id,id)
);
