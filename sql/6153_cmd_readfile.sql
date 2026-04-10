-- Read a file for a given user and path
CREATE OR REPLACE FUNCTION readfile(
  p_username TEXT,
  p_path TEXT
) RETURNS securefile_type AS $$
DECLARE
  v_user_id INT;
  v_file securefile_type;
  v_access file_access;
BEGIN
  -- Resolve user
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get secure file by username and path
  v_file := getsecurefile(p_username, p_path);
  
  IF v_file.is_directory THEN
    IF NOT v_file.read_perm THEN
      RAISE EXCEPTION 'cannot open directory "%": Permission denied', p_path;
    END IF;
  END IF;

  -- Check read permission
  IF NOT (v_file.read_perm) THEN
    RAISE EXCEPTION 'Permission denied to read file "%"', p_path;
  END IF;

  RETURN v_file;
END;
$$ LANGUAGE plpgsql VOLATILE;
