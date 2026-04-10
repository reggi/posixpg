-- readlink: return the target path of a symbolic link
CREATE OR REPLACE FUNCTION readlink(
  p_username TEXT,
  p_path TEXT
) RETURNS TEXT AS $$
DECLARE
  v_user_id INT;
  v_file files%ROWTYPE;
  v_target files%ROWTYPE;
  SYMLINK_TYPE CONSTANT INT := 40960;
  FILE_TYPE_MASK CONSTANT INT := 61440;
BEGIN
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  v_file := filebypath(p_path);
  IF v_file.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  IF (v_file.mode & FILE_TYPE_MASK) != SYMLINK_TYPE THEN
    RAISE EXCEPTION '%: Not a symbolic link', p_path;
  END IF;

  -- Return the target's path
  SELECT * INTO v_target FROM files WHERE file_id = v_file.symbolic_ref;
  IF v_target.file_id IS NULL THEN
    RAISE EXCEPTION 'Broken symbolic link';
  END IF;

  RETURN '/' || array_to_string(v_target.path_array, '/');
END;
$$ LANGUAGE plpgsql;
