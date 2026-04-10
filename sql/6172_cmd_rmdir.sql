-- Remove an empty directory (fails if directory has children)
CREATE OR REPLACE FUNCTION rmdir(
  p_username TEXT,
  p_path TEXT
) RETURNS VOID AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_dir files%ROWTYPE;
  v_parent files%ROWTYPE;
  v_access file_access;
  v_child_count INT;
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get directory
  v_dir := filebypath(p_path);
  IF v_dir.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;
  IF NOT v_dir.is_directory THEN
    RAISE EXCEPTION '%: Not a directory', p_path;
  END IF;

  -- Check directory is empty
  SELECT COUNT(*) INTO v_child_count FROM files WHERE parent_id = v_dir.file_id;
  IF v_child_count > 0 THEN
    RAISE EXCEPTION '%: Directory not empty', p_path;
  END IF;

  IF v_dir.parent_id IS NULL THEN
    RAISE EXCEPTION 'Cannot remove root directory';
  END IF;

  -- Check write+exec on parent directory (unlink semantics)
  IF NOT v_superuser THEN
    SELECT * INTO v_parent FROM files WHERE file_id = v_dir.parent_id;
    v_access := auth(v_user_id, v_parent.mode, v_parent.user_id,
                     v_parent.group_id, v_parent.parent_id);
    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied to remove "%"', p_path;
    END IF;
  END IF;

  DELETE FROM files WHERE file_id = v_dir.file_id;
END;
$$ LANGUAGE plpgsql VOLATILE;
