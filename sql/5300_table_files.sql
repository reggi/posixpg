/*
An llm or agent MUST never remove a comment from
this file, and should never remove existing
functionality without replacing it with new
functionality, for instance don't remove a trigger
or function that is needed.

This SQL file defines the "files" table in
PostgreSQL, which represents a Unix-like file
system structure. The table supports directories,
symbolic links (symlinks), and regular files, with
metadata and constraints to enforce Unix-like
behavior.
*/

CREATE TABLE IF NOT EXISTS files (
  "file_id" SERIAL PRIMARY KEY,
  "created_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "name" TEXT NOT NULL,
  "parent_id" INT REFERENCES files (file_id) ON DELETE CASCADE,
  "user_id" INT REFERENCES users (user_id) NOT NULL,
  "group_id" INT REFERENCES groups (group_id) NOT NULL,
  "mode" INT NOT NULL,
  "size" BIGINT DEFAULT 0 NOT NULL,
  "atime" TIMESTAMPTZ NOT NULL,
  "mtime" TIMESTAMPTZ NOT NULL,
  "structured_data" JSONB,
  "content" TEXT CHECK (octet_length(content) <= 1024 * 1024),
  "blob" TEXT,
  "symbolic_ref" INT REFERENCES files (file_id) ON DELETE SET NULL,
  "is_directory" BOOLEAN DEFAULT FALSE,
  "p_id_n" INT GENERATED ALWAYS AS (COALESCE(parent_id, -1)) STORED,
  "hierarchy_mode" INT NOT NULL,
  "resolved_symbolic_ref" INT REFERENCES files (file_id) ON DELETE SET NULL,
  "path_array" TEXT[] DEFAULT ARRAY[]::TEXT[],
  "resolved_symbolic_mode" INT,
  "resolved_symbolic_hierarchy_mode" INT,
  CONSTRAINT check_nameo_slashes CHECK (position('/' in name) = 0),
  CONSTRAINT unique_item UNIQUE (name, p_id_n),
  CONSTRAINT unique_paths_array UNIQUE (path_array),
  CONSTRAINT check_file_type CHECK (
    (mode & 61440) = 16384
    OR (mode & 61440) = 32768
    OR (mode & 61440) = 40960
  ),
  CONSTRAINT check_root_directory CHECK (
    parent_id IS NOT NULL
    OR ((mode & 61440) = 16384)
  ),
  CHECK (
    (
      ((mode & 61440) = 32768)
      AND (
        (
          CASE
            WHEN structured_data IS NOT NULL THEN 1
            ELSE 0
          END
        ) + (
          CASE
            WHEN content IS NOT NULL THEN 1
            ELSE 0
          END
        ) + (
          CASE
            WHEN blob IS NOT NULL THEN 1
            ELSE 0
          END
        )
      ) = 1
      AND is_directory = FALSE
      AND symbolic_ref IS NULL
    )
    OR (
      ((mode & 61440) = 40960)
      AND structured_data IS NULL
      AND content IS NULL
      AND blob IS NULL
      AND is_directory = FALSE
    )
    OR (
      ((mode & 61440) = 16384)
      AND symbolic_ref IS NULL
      AND structured_data IS NULL
      AND content IS NULL
      AND blob IS NULL
      AND is_directory = TRUE
      AND size = 0
    )
  ),
  CONSTRAINT valid_file_mode CHECK (
    -- Directory types (permissions 000-777) added to 16384
    (
      mode >= 16384
      AND mode <= 17161
    ) -- directory + 000 to 777 (16384 + 0 to 511)
    OR
    -- Symlink types (permissions 000-777) added to 61440
    (
      mode >= 40960
      AND mode <= 41737
    ) -- symlink + 000 to 777 (61440 + 0 to 511)
    OR
    -- Regular file types (permissions 000-777) added to 4096
    (
      mode >= 32768
      AND mode <= 33545
    ) -- file + 000 to 777 (4096 + 0 to 511)
  )
);

CREATE OR REPLACE FUNCTION build_path_array(in_parent_id INT, in_name TEXT)
RETURNS TEXT[] AS $$
DECLARE
  path_parts TEXT[] := ARRAY[in_name];
  current_id INT := in_parent_id;
  current_name TEXT;
BEGIN
  WHILE current_id IS NOT NULL LOOP
    SELECT name, parent_id INTO current_name, current_id
    FROM files WHERE file_id = current_id;

    path_parts := ARRAY[current_name] || path_parts;
  END LOOP;

  RETURN path_parts;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION build_hierarchy_mode(in_parent_id INT)
RETURNS INT AS $$
DECLARE
  m INT;
  h INT;
  dir_mode INT;
BEGIN
  IF in_parent_id IS NULL THEN
    SELECT int INTO dir_mode FROM env WHERE key = 'DEFAULT_DIR_MODE';
    RETURN dir_mode | 16384; -- ensure it's a directory
  END IF;

  SELECT mode, hierarchy_mode INTO m, h
  FROM files WHERE file_id = in_parent_id;

  RETURN m & h;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION resolve_symlink(in_mode INT, in_symbolic_ref INT)
RETURNS files AS $$
DECLARE
  resolved_file files%ROWTYPE;
BEGIN
  IF (in_mode & 40960) <> 40960 THEN
    RETURN NULL;
  END IF;

  WITH RECURSIVE chain AS (
    SELECT f.*, 1 AS depth
    FROM files f
    WHERE f.file_id = in_symbolic_ref

    UNION ALL

    SELECT f.*, c.depth + 1
    FROM files f
    JOIN chain c ON f.file_id = c.symbolic_ref
    WHERE c.depth < 50
  )
  SELECT * INTO resolved_file
  FROM chain
  WHERE (mode & 40960) <> 40960
  ORDER BY depth DESC
  LIMIT 1;

  IF resolved_file.file_id IS NULL THEN
    RAISE EXCEPTION 'Could not resolve symbolic link chain starting at %', in_symbolic_ref;
  END IF;

  RETURN resolved_file;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION before_insert_or_update_files () RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  result RECORD;
  v_resolved files%ROWTYPE;
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;

  IF TG_OP = 'UPDATE' THEN
    IF (OLD.mode & 61440) != (NEW.mode & 61440) THEN
      RAISE EXCEPTION 'Cannot change the file type (mode)';
    END IF;
  END IF;

  IF NEW.parent_id IS NOT NULL AND (TG_OP = 'INSERT' OR NEW.parent_id != OLD.parent_id) THEN
    PERFORM 1 FROM files WHERE file_id = NEW.parent_id AND (mode & 61440) = 16384;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Parent_id must point to a directory';
    END IF;
  END IF;

  NEW.path_array := build_path_array(NEW.parent_id, NEW.name);
  NEW.hierarchy_mode := build_hierarchy_mode(NEW.parent_id);

  v_resolved := resolve_symlink(NEW.mode, NEW.symbolic_ref);

  IF v_resolved.file_id IS NOT NULL THEN
    NEW.resolved_symbolic_ref := v_resolved.file_id;
    NEW.resolved_symbolic_mode := v_resolved.mode;
    NEW.resolved_symbolic_hierarchy_mode := v_resolved.hierarchy_mode;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION propagate_path_array_update(new_row files, old_row files)
RETURNS VOID AS $$
BEGIN
  IF new_row.is_directory AND (
     new_row.name IS DISTINCT FROM old_row.name OR
     new_row.parent_id IS DISTINCT FROM old_row.parent_id
  ) THEN

  -- Recursively update path_array on all descendants
  WITH RECURSIVE descendants AS (
    SELECT f.file_id, f.parent_id, f.name
    FROM files f
    WHERE f.parent_id = new_row.file_id

    UNION ALL

    SELECT f.file_id, f.parent_id, f.name
    FROM files f
    JOIN descendants d ON f.parent_id = d.file_id
  )
  UPDATE files f
  SET path_array = build_path_array(f.parent_id, f.name)
  FROM descendants d
  WHERE f.file_id = d.file_id;

  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION propagate_hierarchy_mode_update(new_row files, old_row files)
RETURNS VOID AS $$
BEGIN
  IF new_row.is_directory AND (
     new_row.mode IS DISTINCT FROM old_row.mode OR
     new_row.parent_id IS DISTINCT FROM old_row.parent_id
  ) THEN

    WITH RECURSIVE descendants AS (
      -- Base case: direct children
      SELECT
        f.file_id,
        f.parent_id,
        (p.mode & p.hierarchy_mode) AS new_hierarchy_mode
      FROM files f
      JOIN files p ON f.parent_id = p.file_id
      WHERE p.file_id = new_row.file_id

      UNION ALL

      -- Recursive case: descendants
      SELECT
        f.file_id,
        f.parent_id,
        (d.new_hierarchy_mode & f.hierarchy_mode) AS new_hierarchy_mode
      FROM files f
      JOIN descendants d ON f.parent_id = d.file_id
    )
    UPDATE files AS f
    SET hierarchy_mode = d.new_hierarchy_mode
    FROM descendants d
    WHERE f.file_id = d.file_id;

  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql;

/* ------------- Update after_insert_or_update_files function to handle name changes and mode changes ------------- */
CREATE OR REPLACE FUNCTION after_insert_or_update_files()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM propagate_path_array_update(NEW, OLD);
  PERFORM propagate_hierarchy_mode_update(NEW, OLD);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Before trigger
CREATE TRIGGER before_insert_or_update_files_trigger BEFORE INSERT
OR
UPDATE ON files FOR EACH ROW
EXECUTE FUNCTION before_insert_or_update_files ();

CREATE TRIGGER after_insert_or_update_files_trigger
AFTER INSERT
OR
UPDATE OF parent_id,
name,
mode ON files FOR EACH ROW
EXECUTE FUNCTION after_insert_or_update_files ();

-- Add users.home_file_id FK after files table creation to avoid circular dependency
ALTER TABLE users
  ADD CONSTRAINT users_home_file_fk FOREIGN KEY (home_file_id) REFERENCES files(file_id);
