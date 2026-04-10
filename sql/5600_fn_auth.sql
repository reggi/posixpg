-- exports: can_traverse, authbase, auth
-- imports: user_groups, users, files

CREATE TYPE file_access AS (
  read_perm BOOLEAN,
  write_perm BOOLEAN,
  execute_perm BOOLEAN
);

-- Walk the parent chain and check exec permission at each ancestor for the specific user.
-- In Unix, traversal requires exec on every directory in the path.
CREATE OR REPLACE FUNCTION can_traverse(p_user_id INT, p_from_parent_id INT)
RETURNS BOOLEAN AS $$
DECLARE
  curr files%ROWTYPE;
  v_in_group BOOLEAN;
  OWNER_EXEC CONSTANT INT := 64;
  GROUP_EXEC CONSTANT INT := 8;
  OTHER_EXEC CONSTANT INT := 1;
  current_id INT := p_from_parent_id;
BEGIN
  IF current_id IS NULL THEN
    RETURN TRUE;
  END IF;

  LOOP
    SELECT * INTO curr FROM files WHERE file_id = current_id;

    IF curr.user_id = p_user_id THEN
      IF (curr.mode & OWNER_EXEC) = 0 THEN RETURN FALSE; END IF;
    ELSE
      SELECT EXISTS(
        SELECT 1 FROM user_groups ug
        WHERE ug.user_id = p_user_id AND ug.group_id = curr.group_id
      ) INTO v_in_group;
      IF v_in_group THEN
        IF (curr.mode & GROUP_EXEC) = 0 THEN RETURN FALSE; END IF;
      ELSE
        IF (curr.mode & OTHER_EXEC) = 0 THEN RETURN FALSE; END IF;
      END IF;
    END IF;

    current_id := curr.parent_id;
    IF current_id IS NULL THEN EXIT; END IF;
  END LOOP;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authbase(
  p_user_id INT,
  file_mode INT,
  p_file_owner_id INT,
  p_file_group_id INT DEFAULT NULL,
  p_file_parent_id INT DEFAULT NULL
) RETURNS file_access AS $$
DECLARE
  OWNER_READ CONSTANT INT := 256;
  OWNER_WRITE CONSTANT INT := 128;
  OWNER_EXEC CONSTANT INT := 64;
  GROUP_READ CONSTANT INT := 32;
  GROUP_WRITE CONSTANT INT := 16;
  GROUP_EXEC CONSTANT INT := 8;
  OTHER_READ CONSTANT INT := 4;
  OTHER_WRITE CONSTANT INT := 2;
  OTHER_EXEC CONSTANT INT := 1;
  FILE_TYPE_MASK CONSTANT INT := 61440;
  DIR_TYPE CONSTANT INT := 16384;
  FILE_TYPE CONSTANT INT := 32768;

  v_file_type TEXT;
  v_in_group BOOLEAN := FALSE;
  v_superuser BOOLEAN := FALSE;
  access file_access;
BEGIN
  -- Superuser bypasses all permission checks
  SELECT superuser INTO v_superuser FROM users WHERE user_id = p_user_id;
  IF v_superuser THEN
    RETURN (TRUE, TRUE, TRUE)::file_access;
  END IF;

  -- Check traversal: user must have exec on every ancestor directory
  IF NOT can_traverse(p_user_id, p_file_parent_id) THEN
    RETURN (FALSE, FALSE, FALSE)::file_access;
  END IF;

  -- Determine file type
  IF (file_mode & FILE_TYPE_MASK) = DIR_TYPE THEN
    v_file_type := 'directory';
  ELSIF (file_mode & FILE_TYPE_MASK) = FILE_TYPE THEN
    v_file_type := 'file';
  ELSE
    RAISE EXCEPTION 'Unknown file type with mode %', file_mode;
  END IF;

  -- Check group membership (only if not owner)
  IF p_file_group_id IS NOT NULL AND p_file_owner_id != p_user_id THEN
    SELECT EXISTS(
      SELECT 1 FROM user_groups ug
      WHERE ug.user_id = p_user_id AND ug.group_id = p_file_group_id
    ) INTO v_in_group;
  END IF;

  -- Read access: check file's own mode bits only (traversal already verified)
  access.read_perm := CASE
    WHEN p_file_owner_id = p_user_id THEN (file_mode & OWNER_READ) > 0
    WHEN v_in_group THEN (file_mode & GROUP_READ) > 0
    ELSE (file_mode & OTHER_READ) > 0
  END;

  -- Write access: check file's own mode bits only
  access.write_perm := CASE
    WHEN p_file_owner_id = p_user_id THEN (file_mode & OWNER_WRITE) > 0
    WHEN v_in_group THEN (file_mode & GROUP_WRITE) > 0
    ELSE (file_mode & OTHER_WRITE) > 0
  END;

  -- Execute access: check file's own mode bits only
  access.execute_perm := CASE
    WHEN p_file_owner_id = p_user_id THEN (file_mode & OWNER_EXEC) > 0
    WHEN v_in_group THEN (file_mode & GROUP_EXEC) > 0
    ELSE (file_mode & OTHER_EXEC) > 0
  END;

  RETURN access;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION auth(
  p_user_id INT,
  file_mode INT,
  p_file_owner_id INT,
  p_file_group_id INT DEFAULT NULL,
  p_file_parent_id INT DEFAULT NULL,
  p_resolved_ref INT DEFAULT NULL
) RETURNS file_access AS $$
DECLARE
  SYMLINK_TYPE CONSTANT INT := 40960;
  FILE_TYPE_MASK CONSTANT INT := 61440;
  v_target files%ROWTYPE;
BEGIN
  -- If this is a symlink, check permissions on the resolved target
  IF (file_mode & FILE_TYPE_MASK) = SYMLINK_TYPE THEN
    IF p_resolved_ref IS NOT NULL THEN
      SELECT * INTO v_target FROM files WHERE file_id = p_resolved_ref;
      IF v_target.file_id IS NOT NULL THEN
        RETURN authbase(p_user_id, v_target.mode, v_target.user_id, v_target.group_id, v_target.parent_id);
      END IF;
    END IF;
    RAISE EXCEPTION 'Could not resolve symlink target';
  END IF;
  -- Regular permission check
  RETURN authbase(p_user_id, file_mode, p_file_owner_id, p_file_group_id, p_file_parent_id);
END;
$$ LANGUAGE plpgsql;
