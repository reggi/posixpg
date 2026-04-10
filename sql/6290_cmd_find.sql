-- find: search for files by name pattern under a directory
-- Supports basic glob matching (* and ?)
CREATE OR REPLACE FUNCTION find(
  p_username TEXT,
  p_path TEXT,
  p_name TEXT DEFAULT NULL
) RETURNS SETOF TEXT AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_dir files%ROWTYPE;
  v_access file_access;
  v_pattern TEXT;
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Resolve starting directory
  v_dir := filebypath(p_path);
  IF v_dir.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;
  IF NOT v_dir.is_directory THEN
    RAISE EXCEPTION '%: Not a directory', p_path;
  END IF;

  -- Check access to starting directory
  IF NOT v_superuser THEN
    v_access := auth(v_user_id, v_dir.mode, v_dir.user_id, v_dir.group_id, v_dir.parent_id);
    IF NOT (v_access.read_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied on "%"', p_path;
    END IF;
  END IF;

  -- Convert glob pattern to SQL LIKE pattern (NULL = match all)
  IF p_name IS NOT NULL THEN
    v_pattern := replace(replace(p_name, '*', '%'), '?', '_');
  END IF;

  -- Recursively find all descendants
  RETURN QUERY
    WITH RECURSIVE descendants AS (
      SELECT file_id, name, parent_id, path_array, is_directory
      FROM files WHERE parent_id = v_dir.file_id

      UNION ALL

      SELECT f.file_id, f.name, f.parent_id, f.path_array, f.is_directory
      FROM files f
      JOIN descendants d ON f.parent_id = d.file_id
      WHERE d.is_directory
    )
    SELECT '/' || array_to_string(d.path_array, '/')
    FROM descendants d
    WHERE v_pattern IS NULL OR d.name LIKE v_pattern
    ORDER BY d.path_array;
END;
$$ LANGUAGE plpgsql;
