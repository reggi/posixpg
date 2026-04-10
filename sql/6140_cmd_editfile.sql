-- Create appendfile function to append content to a file for a given user and path
CREATE OR REPLACE FUNCTION editfile(
  p_username TEXT,
  p_path TEXT,
  p_content TEXT DEFAULT '',
  p_append BOOLEAN DEFAULT FALSE
) RETURNS SETOF files AS $$
DECLARE
  v_user_id INT;
  v_file files%ROWTYPE;
  v_parent files%ROWTYPE;
  v_access file_access;
  v_rec files%ROWTYPE;
  v_file_exists BOOLEAN;
BEGIN
  -- Resolve user
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Check if file exists
  SELECT EXISTS (
    SELECT 1 FROM files WHERE path_array = (parsepath(p_path)).path_array
  ) INTO v_file_exists;

  IF v_file_exists THEN
    -- File exists: get file and check write permission
    v_file := filebypath(p_path);
    v_access := auth(
      v_user_id,
      v_file.mode,
      v_file.user_id,
      v_file.group_id,
      v_file.parent_id,
      v_file.resolved_symbolic_ref
    );
    IF NOT (v_access.write_perm) THEN
      RAISE EXCEPTION 'Permission denied to write to file "%"', p_path;
    END IF;
    -- Update file
    UPDATE files
    SET
      content = CASE WHEN p_append THEN COALESCE(content, '') || p_content ELSE p_content END,
      size = octet_length(CASE WHEN p_append THEN COALESCE(content, '') || p_content ELSE p_content END),
      mtime = CURRENT_TIMESTAMP
    WHERE file_id = v_file.file_id
    RETURNING * INTO v_rec;
  ELSE
    -- File does not exist: get parent directory and check write+execute permission
    v_parent := parentbypath(p_path);
    IF NOT v_parent.is_directory THEN
      RAISE EXCEPTION 'Parent path of "%" is not a directory', p_path;
    END IF;
    v_access := auth(
      v_user_id,
      v_parent.mode,
      v_parent.user_id,
      v_parent.group_id,
      v_parent.parent_id
    );
    IF NOT (v_access.write_perm AND v_access.execute_perm) THEN
      RAISE EXCEPTION 'Permission denied to create file in directory "%"', v_parent.name;
    END IF;
    -- Insert new file (apply umask: mode 666 & ~umask)
    DECLARE
      v_umask INT;
      v_file_mode INT;
    BEGIN
      SELECT COALESCE((SELECT int FROM env WHERE key = 'UMASK'), octal(22)) INTO v_umask;
      v_file_mode := 32768 + (438 & ~v_umask); -- 438 = octal(666), 32768 = regular file type
      INSERT INTO files (name, parent_id, user_id, group_id, mode, size, atime, mtime, is_directory, hierarchy_mode, content)
      VALUES (
        ((parsepath(p_path)).name),
        v_parent.file_id,
        v_user_id,
        v_parent.group_id,
        v_file_mode,
        octet_length(p_content),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        FALSE,
        v_parent.hierarchy_mode,
        p_content
      )
      RETURNING * INTO v_rec;
    END;
  END IF;

  RETURN NEXT v_rec;
  RETURN;
END;
$$ LANGUAGE plpgsql VOLATILE;
