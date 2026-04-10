-- Change a file's group for a given user and path
CREATE OR REPLACE FUNCTION addusertogroup(
  p_username TEXT,
  p_groupname TEXT
) RETURNS void AS $$
DECLARE
  v_user_id     INT;
  v_group_id    INT;
BEGIN
   SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  SELECT group_id INTO v_group_id FROM groups WHERE "group" = p_groupname;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group "%" not found', p_groupname;
  END IF;

  BEGIN
    INSERT INTO user_groups (user_id, group_id)
    VALUES (v_user_id, v_group_id);
  EXCEPTION WHEN unique_violation THEN
    -- User is already in the group, do nothing
    NULL;
  END;

END;
$$ LANGUAGE plpgsql VOLATILE;

