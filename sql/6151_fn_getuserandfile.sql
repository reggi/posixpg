CREATE TYPE user_and_file AS (
  "user" users,
  "file" vfiles
);

CREATE OR REPLACE FUNCTION getuserandfile(
  p_username TEXT,
  p_path TEXT
) RETURNS user_and_file AS $$
DECLARE
  v_file vfiles%ROWTYPE;
  v_user users%ROWTYPE;
BEGIN
  SELECT * INTO v_file FROM filebypath(p_path) AS f;
  IF NOT FOUND THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  SELECT * INTO v_user FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  RETURN (v_user, v_file);
END;
$$ LANGUAGE plpgsql;
