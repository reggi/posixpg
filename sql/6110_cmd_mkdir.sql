-- $1: abs_path (TEXT) - Absolute path of the directory to create
-- $2: p_username (TEXT) - Username creating the directory

CREATE OR REPLACE FUNCTION mkdir(p_username TEXT, abs_path TEXT, p_mode INT DEFAULT NULL)
RETURNS files AS $$
DECLARE
  dir_mode INT;
  v_parent_id INT;
  dir_name TEXT;
  created_dir files%ROWTYPE;
  path_parts TEXT[];
  i INT;
  curr_id INT;
  exists_id INT;
  user_id INT;
  v_superuser BOOLEAN;
  group_id INT;
  parent_owner_id INT;
  parent_group_id INT;
  parent_parent_id INT;
  parent_mode INT;
  v_access file_access;
BEGIN
  -- Lookup user_id by username
  SELECT u.user_id, u.superuser INTO user_id, v_superuser FROM users u WHERE u.username = p_username;
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'User "%" does not exist', p_username;
  END IF;

  -- Lookup group_id by group name (same as username)
  SELECT g.group_id INTO group_id FROM groups g WHERE g."group" = p_username;
  IF group_id IS NULL THEN
    RAISE EXCEPTION 'Default group "%" does not exist', p_username;
  END IF;

  -- Step 0: Determine the directory mode based on p_mode or env
  IF p_mode IS NOT NULL THEN
    dir_mode := octal(p_mode);
  ELSE
    DECLARE
      v_umask INT;
      v_default_mode INT;
    BEGIN
      SELECT int INTO v_default_mode FROM env WHERE key = 'DEFAULT_DIR_MODE';
      IF v_default_mode IS NULL THEN
        RAISE EXCEPTION 'DEFAULT_DIR_MODE key does not exist in the env table or has no value';
      END IF;
      SELECT COALESCE((SELECT int FROM env WHERE key = 'UMASK'), octal(22)) INTO v_umask;
      dir_mode := v_default_mode & ~v_umask;
    END;
  END IF;

  -- Ensure dir_mode includes the directory type
  dir_mode := dir_mode | 16384;

  -- Step 1: Parse the path and find the parent directory
  IF abs_path IS NULL OR abs_path = '' OR abs_path = '/' THEN
    RAISE EXCEPTION 'Invalid path';
  END IF;

  -- Remove trailing slash if present
  IF right(abs_path, 1) = '/' THEN
    abs_path := left(abs_path, length(abs_path) - 1);
  END IF;

  -- Remove leading slash if present to avoid empty first element in path_parts
  IF left(abs_path, 1) = '/' THEN
    abs_path := right(abs_path, length(abs_path) - 1);
  END IF;

  path_parts := string_to_array(abs_path, '/');
  dir_name := path_parts[array_length(path_parts, 1)];

  -- If creating a direct child of root (e.g., /user), set v_parent_id to NULL
  IF array_length(path_parts, 1) = 1 THEN
    v_parent_id := NULL;
  ELSE
    -- Find parent directory by traversing the path starting from root (NULL parent)
    curr_id := NULL;
    FOR i IN 1..array_length(path_parts, 1) - 1 LOOP
      SELECT f.file_id INTO curr_id
      FROM files f
      WHERE f.parent_id IS NOT DISTINCT FROM curr_id
        AND f.name = path_parts[i]
        AND f.is_directory = TRUE;

      IF curr_id IS NULL THEN
        RAISE EXCEPTION 'Parent directory "%" does not exist', path_parts[i];
      END IF;
    END LOOP;

    v_parent_id := curr_id;
  END IF;

  -- Only superuser can create root directories
  IF v_parent_id IS NULL AND v_superuser IS NOT TRUE THEN
    RAISE EXCEPTION 'Only superuser can create root directories';
  END IF;

  -- Step 1.5: Authorization check on parent directory
  IF v_parent_id IS NOT NULL THEN
    -- Retrieve parent directory permissions and ownership
    SELECT f.user_id, f.group_id, f.parent_id, f.mode
      INTO parent_owner_id, parent_group_id, parent_parent_id, parent_mode
    FROM files f WHERE f.file_id = v_parent_id;
    -- Check write and execute permissions via auth
    v_access := auth(
      user_id,                       -- p_user_id
      parent_mode,                   -- file_mode
      parent_owner_id,               -- p_file_owner_id
      parent_group_id,               -- p_file_group_id
      parent_parent_id               -- p_file_parent_id
    );
    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied for user "%" on parent directory "%"', p_username, abs_path;
    END IF;
  END IF;

  -- Check if directory already exists
  SELECT f.file_id INTO exists_id
  FROM files f
  WHERE f.parent_id IS NOT DISTINCT FROM v_parent_id AND f.name = dir_name AND f.is_directory = TRUE;

  IF exists_id IS NOT NULL THEN
    RAISE EXCEPTION 'Directory "%" already exists', abs_path;
  END IF;

  -- Step 2: Create the directory
  INSERT INTO files (
    name,
    parent_id,
    user_id,
    group_id,
    mode,
    size,
    atime,
    mtime,
    is_directory,
    hierarchy_mode
  )
  VALUES (
    dir_name,
    v_parent_id,
    user_id,
    group_id,
    dir_mode,
    0,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    TRUE,
    dir_mode
  )
  RETURNING * INTO created_dir;

  RETURN created_dir;
END;
$$ LANGUAGE plpgsql;
