CREATE OR REPLACE FUNCTION deleteuser(
  p_username TEXT
) RETURNS VOID AS $$
DECLARE
  v_user_id INT;
  v_group_id INT;
  v_home_file_id INT;
BEGIN
  -- Resolve user
  SELECT user_id, home_file_id INTO v_user_id, v_home_file_id
  FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get the user's primary group
  SELECT group_id INTO v_group_id FROM groups WHERE "group" = p_username;

  -- Clear home_file_id FK before deleting files
  UPDATE users SET home_file_id = NULL WHERE user_id = v_user_id;

  -- Delete user's owned files (cascades to children via parent_id FK)
  DELETE FROM files WHERE user_id = v_user_id;

  -- Delete user_groups memberships (cascaded by FK, but explicit for clarity)
  DELETE FROM user_groups WHERE user_id = v_user_id;

  -- Delete user_files associations
  DELETE FROM user_files WHERE user_id = v_user_id;

  -- Delete the user
  DELETE FROM users WHERE user_id = v_user_id;

  -- Delete the user's primary group (if no other members)
  IF v_group_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM user_groups WHERE group_id = v_group_id) THEN
      DELETE FROM groups WHERE group_id = v_group_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;
