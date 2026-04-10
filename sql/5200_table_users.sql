CREATE TABLE IF NOT EXISTS users (
  "user_id" SERIAL PRIMARY KEY,
  "username" TEXT UNIQUE NOT NULL,
  "password_hash" TEXT NOT NULL,
  "created_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "superuser" BOOLEAN DEFAULT FALSE NOT NULL,
  "home_file_id" INT
);

CREATE TRIGGER set_updated_at BEFORE
UPDATE ON users FOR EACH ROW
EXECUTE FUNCTION updated_at ();

-- Foreign key constraint removed to avoid circular dependency; will be added after files table creation
