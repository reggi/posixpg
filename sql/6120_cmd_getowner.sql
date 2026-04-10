CREATE OR REPLACE FUNCTION getowner(abs_path TEXT)
RETURNS TEXT AS $$
DECLARE
  f files%ROWTYPE;
  username TEXT;
BEGIN
  f := filebypath(abs_path);

  SELECT u.username INTO username
  FROM users u
  WHERE u.user_id = f.user_id;

  IF username IS NULL THEN
    RAISE EXCEPTION 'Owner user_id "%" not found for file "%"', f.user_id, abs_path;
  END IF;

  RETURN username;
END;
$$ LANGUAGE plpgsql;
