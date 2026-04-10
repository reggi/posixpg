CREATE TABLE IF NOT EXISTS env (
  id SERIAL PRIMARY KEY,       -- Auto-incrementing primary key
  key VARCHAR(255) NOT NULL UNIQUE, -- Key column, must be unique
  text TEXT,                  -- Value column, can store any text
  int INT,                    -- Integer value, can be NULL
  user_id INT NULL,           -- Nullable user_id column
  file_id INT NULL,           -- Nullable file_id column
  "created_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
  CONSTRAINT one_value_only CHECK (
    (CASE WHEN text     IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN int      IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN user_id  IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN file_id  IS NOT NULL THEN 1 ELSE 0 END) = 1
  )
)
