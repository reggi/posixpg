-- Create a composite type for parsed path
CREATE TYPE user_data AS (
  "username" TEXT,
  "group" TEXT,
  "home" TEXT,
  "superuser" BOOLEAN
);

-- Returns user_data for a given username
CREATE OR REPLACE FUNCTION id(p_username TEXT)
RETURNS user_data AS $$
DECLARE
  v_user RECORD;
  v_group RECORD;
  v_home RECORD;
  home_path TEXT;
  result user_data;
BEGIN
  -- Find user
  SELECT * INTO v_user FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Find group (default group is same as username)
  SELECT * INTO v_group FROM groups WHERE "group" = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group for user "%" not found', p_username;
  END IF;

  -- Find home directory file
  IF v_user.home_file_id IS NULL THEN
    home_path := NULL;
  ELSE
    SELECT * INTO v_home FROM files WHERE file_id = v_user.home_file_id;
    IF NOT FOUND THEN
      home_path := NULL;
    ELSE
      -- Assemble path from path_array
      home_path := '/' || array_to_string(v_home.path_array, '/');
    END IF;
  END IF;

  -- Assemble result
  result := (v_user.username, v_group."group", home_path, v_user.superuser);
  RETURN result;
END;
$$ LANGUAGE plpgsql;
