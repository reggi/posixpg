-- List all groups a user belongs to
CREATE OR REPLACE FUNCTION listusergroups(
  p_username TEXT
) RETURNS TABLE(group_id INT, "group" TEXT) AS $$
DECLARE
  v_user_id     INT;
BEGIN
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  RETURN QUERY
    SELECT DISTINCT ON (g.group)
      g.group_id,
      g.group AS "group"
    FROM user_groups ug
    JOIN groups g ON ug.group_id = g.group_id
    WHERE ug.user_id = v_user_id
    ORDER BY g.group;

END;
$$ LANGUAGE plpgsql VOLATILE;
