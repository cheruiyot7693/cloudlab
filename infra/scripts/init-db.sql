-- CloudLab Platform — DB Initialization
-- Runs once when the postgres container starts for the first time.
-- Full schema migrations are managed by Alembic (Phase 1).

-- Create test database for CI
CREATE DATABASE cloudlab_test;
GRANT ALL PRIVILEGES ON DATABASE cloudlab_test TO cloudlab;
