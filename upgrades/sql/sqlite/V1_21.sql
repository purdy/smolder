ALTER TABLE smoke_report ADD COLUMN todo_pass INTEGER DEFAULT 0;
ALTER TABLE project ADD COLUMN enable_feed INTEGER DEFAULT 1;
DROP TABLE project_category;
