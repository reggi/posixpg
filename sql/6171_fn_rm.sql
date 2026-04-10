-- Delete a file or directory (Unix unlink/rm -r semantics)
CREATE OR REPLACE FUNCTION rm(
  p_username TEXT,
  p_path TEXT
) RETURNS VOID AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_file RECORD;
  v_parent files%ROWTYPE;
  v_access file_access;
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get file by path
  SELECT * INTO v_file FROM filebypath(p_path) AS f;
  IF v_file.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  IF v_file.parent_id IS NULL THEN
    RAISE EXCEPTION 'Cannot delete root directory';
  END IF;

  -- Unix unlink checks write+execute on the PARENT directory
  IF NOT v_superuser THEN
    SELECT * INTO v_parent FROM files WHERE file_id = v_file.parent_id;

    v_access := auth(
      v_user_id,
      v_parent.mode,
      v_parent.user_id,
      v_parent.group_id,
      v_parent.parent_id
    );

    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied to delete "%"', p_path;
    END IF;
  END IF;

  -- Delete the file (CASCADE on parent_id handles children for directories)
  DELETE FROM files WHERE file_id = v_file.file_id;

END;
$$ LANGUAGE plpgsql VOLATILE;
