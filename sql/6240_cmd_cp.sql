-- Copy a file (not directories)
CREATE OR REPLACE FUNCTION cp(
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
  v_group_id INT;
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
  IF v_src.is_directory THEN
    RAISE EXCEPTION 'Cannot copy directory "%"', p_src;
  END IF;

  -- Check read permission on source
  IF NOT v_superuser THEN
    v_access := auth(v_user_id, v_src.mode, v_src.user_id, v_src.group_id, v_src.parent_id);
    IF NOT v_access.read_perm THEN
      RAISE EXCEPTION 'Permission denied to read "%"', p_src;
    END IF;
  END IF;

  -- Parse destination
  v_dest_parsed := parsepath(p_dest);
  SELECT * INTO v_dest_parent FROM files WHERE path_array = v_dest_parsed.dirname_array;
  IF v_dest_parent.file_id IS NULL THEN
    RAISE EXCEPTION 'Destination directory does not exist';
  END IF;

  -- Check write+exec on destination parent
  IF NOT v_superuser THEN
    v_access := auth(v_user_id, v_dest_parent.mode, v_dest_parent.user_id,
                     v_dest_parent.group_id, v_dest_parent.parent_id);
    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied on destination directory';
    END IF;
  END IF;

  -- Get user's default group
  SELECT g.group_id INTO v_group_id FROM groups g WHERE g."group" = p_username;

  -- Insert copy (new file owned by copying user)
  INSERT INTO files (name, parent_id, user_id, group_id, mode, size, atime, mtime,
                     is_directory, hierarchy_mode, content, blob, structured_data)
  VALUES (
    v_dest_parsed.name,
    v_dest_parent.file_id,
    v_user_id,
    COALESCE(v_group_id, v_dest_parent.group_id),
    v_src.mode,
    v_src.size,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    FALSE,
    v_dest_parent.hierarchy_mode,
    v_src.content,
    v_src.blob,
    v_src.structured_data
  );
END;
$$ LANGUAGE plpgsql VOLATILE;
