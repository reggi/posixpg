-- Read a file for a given user and path
CREATE OR REPLACE FUNCTION ln(
  p_username TEXT,
  p_src TEXT,
  p_dest TEXT
) RETURNS securefile_type AS $$
DECLARE
  v_user users%ROWTYPE;
  v_file securefile_type;
  v_access file_access;
  new_file_id INT;
  target_file_id INT;
  v_parsed parsed_path;
  v_parent files%ROWTYPE;
  v_new_file files%ROWTYPE;
  v_vfile vfiles%ROWTYPE;
BEGIN
  -- Resolve user
  SELECT * INTO v_user FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get secure file by username and path
  v_file := getsecurefile(p_username, p_src);
  
  IF v_file.is_directory THEN
    IF NOT v_file.read_perm THEN
      RAISE EXCEPTION 'cannot open directory "%": Permission denied', p_src;
    END IF;
  END IF;

  -- Check read permission
  IF NOT (v_file.read_perm) THEN
    RAISE EXCEPTION 'Permission denied to read file "%"', p_src;
  END IF;

  -- Parse destination path
  v_parsed := parsepath(p_dest);
  SELECT * INTO v_parent FROM files WHERE path_array = v_parsed.dirname_array;

  -- Insert the symbolic link file (assuming files table has symbolic_ref and path columns)
  INSERT INTO files (
    "name",
    "user_id",
    "group_id",
    "mode",
    "atime",
    "mtime",
    "hierarchy_mode",
    "parent_id",
    "symbolic_ref" -- add this column if it exists
  ) VALUES (
    v_parsed.name,
    v_user.user_id,
    v_parent.group_id,
    40960, -- mode for symlink
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    40960, -- hierarchy_mode for symlink (this will get replaced by the trigger)
    v_parent.file_id,
    v_file.file_id -- reference to the source file
  )
  RETURNING * INTO v_new_file;

  SELECT * INTO v_vfile FROM vfiles WHERE file_id = v_new_file.file_id;

  -- Return the new file as securefile_type
  RETURN securefile(v_user, v_vfile);
END;
$$ LANGUAGE plpgsql VOLATILE;
