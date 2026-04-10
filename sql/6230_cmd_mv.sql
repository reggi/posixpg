-- Move/rename a file or directory
CREATE OR REPLACE FUNCTION mv(
  p_username TEXT,
  p_src TEXT,
  p_dest TEXT
) RETURNS VOID AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_src files%ROWTYPE;
  v_dest_parsed parsed_path;
  v_dest_parent files%ROWTYPE;
  v_access file_access;
  v_existing INT;
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get source file
  v_src := filebypath(p_src);
  IF v_src.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_src;
  END IF;

  -- Check write+exec on source's parent directory (needed to unlink from source)
  IF v_src.parent_id IS NOT NULL AND NOT v_superuser THEN
    v_access := auth(v_user_id, (SELECT mode FROM files WHERE file_id = v_src.parent_id),
                     (SELECT user_id FROM files WHERE file_id = v_src.parent_id),
                     (SELECT group_id FROM files WHERE file_id = v_src.parent_id),
                     v_src.parent_id);
    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied to move "%"', p_src;
    END IF;
  END IF;

  -- Parse destination path
  v_dest_parsed := parsepath(p_dest);

  -- Get destination parent directory
  SELECT * INTO v_dest_parent FROM files WHERE path_array = v_dest_parsed.dirname_array;
  IF v_dest_parent.file_id IS NULL THEN
    RAISE EXCEPTION 'Destination directory does not exist';
  END IF;
  IF NOT v_dest_parent.is_directory THEN
    RAISE EXCEPTION 'Destination parent is not a directory';
  END IF;

  -- Check write+exec on destination parent
  IF NOT v_superuser THEN
    v_access := auth(v_user_id, v_dest_parent.mode, v_dest_parent.user_id,
                     v_dest_parent.group_id, v_dest_parent.parent_id);
    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied on destination directory';
    END IF;
  END IF;

  -- Check if destination name already exists
  SELECT file_id INTO v_existing FROM files
  WHERE parent_id = v_dest_parent.file_id AND name = v_dest_parsed.name;
  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'Destination "%" already exists', p_dest;
  END IF;

  -- Move: update parent_id and name
  UPDATE files SET
    parent_id = v_dest_parent.file_id,
    name = v_dest_parsed.name
  WHERE file_id = v_src.file_id;
END;
$$ LANGUAGE plpgsql VOLATILE;
