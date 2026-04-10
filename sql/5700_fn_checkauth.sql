-- New function to check authorization by username and path
CREATE OR REPLACE FUNCTION checkauth(
  p_username TEXT,
  p_path TEXT
) RETURNS file_access AS $$
DECLARE
  v_user_id INT;
  v_file RECORD;
BEGIN
  -- Lookup user id
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Lookup file by path using filebypath
  SELECT * INTO v_file FROM filebypath(p_path) AS f;

  -- Call auth with resolved parameters
  RETURN auth(
    v_user_id,
    v_file.mode,
    v_file.user_id,
    v_file.group_id,
    v_file.parent_id,
    v_file.resolved_symbolic_ref
  );
END;
$$ LANGUAGE plpgsql;
