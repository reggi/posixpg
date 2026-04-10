-- chmod -R: recursively change permissions on a directory tree
CREATE OR REPLACE FUNCTION chmod_r(
  p_username TEXT,
  p_mode INT,
  p_path TEXT
) RETURNS VOID AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_file files%ROWTYPE;
  v_perm_bits INT;
  v_type_bits INT;
  v_new_mode INT;
  v_child RECORD;
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get file
  v_file := filebypath(p_path);
  IF v_file.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  -- Permission: Only owner or superuser can chmod
  IF v_file.user_id != v_user_id AND NOT v_superuser THEN
    RAISE EXCEPTION 'Permission denied to change mode of "%"', p_path;
  END IF;

  -- Convert octal mode to permission bits
  v_perm_bits := ((p_mode / 100) % 10) * 64
              + ((p_mode / 10)  % 10) * 8
              + ( p_mode        % 10);

  -- Update this file
  v_type_bits := v_file.mode & ~511;
  v_new_mode := v_type_bits + v_perm_bits;
  UPDATE files SET mode = v_new_mode WHERE file_id = v_file.file_id;

  -- If directory, recurse into all descendants
  IF v_file.is_directory THEN
    WITH RECURSIVE descendants AS (
      SELECT file_id, mode FROM files WHERE parent_id = v_file.file_id
      UNION ALL
      SELECT f.file_id, f.mode FROM files f JOIN descendants d ON f.parent_id = d.file_id
    )
    UPDATE files f
    SET mode = (f.mode & ~511) + v_perm_bits
    FROM descendants d
    WHERE f.file_id = d.file_id;
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;
