-- Change a file's group for a given user and path
CREATE OR REPLACE FUNCTION chgrp(
  p_username TEXT,
  p_groupname TEXT,
  p_path TEXT
) RETURNS SETOF files AS $$
DECLARE
  v_user_id     INT;
  v_superuser   BOOLEAN;
  v_file        files%ROWTYPE;
  v_group_id    INT;
  v_is_member   BOOLEAN;
BEGIN
  -- Resolve user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Get file by path
  v_file := filebypath(p_path);
  IF v_file.file_id IS NULL THEN
    RAISE EXCEPTION 'File "%" not found', p_path;
  END IF;

  -- Get group id
  SELECT group_id INTO v_group_id FROM groups WHERE "group" = p_groupname;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group "%" not found', p_groupname;
  END IF;

  -- Permission: Only owner or superuser can chgrp
  IF v_file.user_id != v_user_id AND NOT v_superuser THEN
    RAISE EXCEPTION 'Permission denied to change group of "%"', p_path;
  END IF;

  -- User must be a member of the group or superuser
  SELECT EXISTS(
    SELECT 1 FROM user_groups WHERE user_id = v_user_id AND group_id = v_group_id
  ) INTO v_is_member;
  IF NOT v_is_member AND NOT v_superuser THEN
    RAISE EXCEPTION 'User "%" is not a member of group "%"', p_username, p_groupname;
  END IF;

  -- Update the group_id of the file
  UPDATE files
    SET group_id = v_group_id
  WHERE file_id = v_file.file_id
  RETURNING * INTO v_file;

  RETURN NEXT v_file;
  RETURN;
END;
$$ LANGUAGE plpgsql VOLATILE;

