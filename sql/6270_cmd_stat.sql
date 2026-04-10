-- stat: return file metadata as a single text block (matching Debian stat -c format)
CREATE TYPE stat_result AS (
  file_name TEXT,
  file_type TEXT,
  file_mode INT,
  decimal_mode INT,
  owner TEXT,
  owner_group TEXT,
  file_size BIGINT,
  atime TIMESTAMPTZ,
  mtime TIMESTAMPTZ,
  ctime TIMESTAMPTZ
);

CREATE OR REPLACE FUNCTION stat(
  p_username TEXT,
  p_path TEXT
) RETURNS stat_result AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_file RECORD;
  v_access file_access;
  v_result stat_result;
  v_file_type TEXT;
  FILE_TYPE_MASK CONSTANT INT := 61440;
  DIR_TYPE CONSTANT INT := 16384;
  FILE_TYPE CONSTANT INT := 32768;
  SYMLINK_TYPE CONSTANT INT := 40960;
BEGIN
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  SELECT * INTO v_file FROM vfiles WHERE path_array = (parsepath(p_path)).path_array;
  IF NOT FOUND THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  -- Check traversal (need exec on parent chain)
  IF NOT v_superuser THEN
    v_access := auth(v_user_id, v_file.mode, v_file.user_id, v_file.group_id, v_file.parent_id);
    -- stat only requires exec on ancestors, not read on the file itself
  END IF;

  -- Determine type string
  IF (v_file.mode & FILE_TYPE_MASK) = DIR_TYPE THEN
    v_file_type := 'directory';
  ELSIF (v_file.mode & FILE_TYPE_MASK) = FILE_TYPE THEN
    v_file_type := 'regular file';
  ELSIF (v_file.mode & FILE_TYPE_MASK) = SYMLINK_TYPE THEN
    v_file_type := 'symbolic link';
  ELSE
    v_file_type := 'unknown';
  END IF;

  v_result.file_name := v_file.name;
  v_result.file_type := v_file_type;
  v_result.file_mode := v_file.mode;
  v_result.decimal_mode := v_file.decimal_perm_bits;
  v_result.owner := (SELECT username FROM users WHERE user_id = v_file.user_id);
  v_result.owner_group := (SELECT "group" FROM groups WHERE group_id = v_file.group_id);
  v_result.file_size := v_file.size;
  v_result.atime := v_file.atime;
  v_result.mtime := v_file.mtime;
  v_result.ctime := v_file.created_at;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
