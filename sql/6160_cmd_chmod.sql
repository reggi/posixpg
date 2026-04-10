-- Read (and now change) a file’s mode for a given user and path
CREATE OR REPLACE FUNCTION chmod(
  p_username TEXT,
  p_mode     INT,
  p_path     TEXT
) RETURNS SETOF files AS $$
DECLARE
  v_user_id     INT;
  v_superuser   BOOLEAN;
  v_file        files%ROWTYPE;
  v_access      file_access;
  v_perm_bits   INT;    -- new: permission bits from p_mode
  v_type_bits   INT;    -- new: existing file-type bits
  v_new_mode    INT;    -- new: sum of type + permission bits
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get file by path
  v_file := filebypath(p_path);
  IF v_file.file_id IS NULL THEN
    RAISE EXCEPTION 'File "%" not found', p_path;
  END IF;

  -- Permission: Only owner or superuser can chmod
  IF v_file.user_id != v_user_id AND NOT v_superuser THEN
    RAISE EXCEPTION 'Permission denied to change mode of "%"', p_path;
  END IF;

  -- Convert decimal “octal” like 755 into real permission bits
  v_perm_bits := ((p_mode / 100) % 10) * 64
              + ((p_mode / 10)  % 10) * 8
              + ( p_mode        % 10);

  -- Extract the file‐type bits (everything but the low 9 permission bits)
  v_type_bits := v_file.mode & ~511;    -- 511 = 0o777

  -- Compute and apply the new mode
  v_new_mode := v_type_bits + v_perm_bits;
  UPDATE files
    SET mode = v_new_mode
  WHERE file_id = v_file.file_id
  RETURNING * INTO v_file;

  RETURN NEXT v_file;
  RETURN;
END;
$$ LANGUAGE plpgsql VOLATILE;
