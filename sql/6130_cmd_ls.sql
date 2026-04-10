-- Create ls function to list directory contents for a given user and path
CREATE OR REPLACE FUNCTION ls(
  p_username TEXT,
  p_path TEXT
) RETURNS SETOF files AS $$
DECLARE
  v_user_id INT;
  v_dir files%ROWTYPE;
  v_access file_access;
  v_rec files%ROWTYPE;
BEGIN
  -- Resolve user
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Resolve directory by path
  v_dir := filebypath(p_path);
  IF NOT v_dir.is_directory THEN
    RAISE EXCEPTION 'Path "%" is not a directory', p_path;
  END IF;

  -- Check directory permissions
  v_access := auth(
    v_user_id,
    v_dir.mode,
    v_dir.user_id,
    v_dir.group_id,
    v_dir.parent_id
  );
  IF NOT (v_access.read_perm AND v_access.execute_perm) THEN
    RAISE EXCEPTION 'Permission denied on directory "%"', p_path;
  END IF;

  -- List files in directory
  FOR v_rec IN
    SELECT * FROM files WHERE parent_id = v_dir.file_id ORDER BY name
  LOOP
    RETURN NEXT v_rec;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql STABLE;
