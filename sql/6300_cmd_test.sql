-- test: check file existence and type
-- flag: 'e' = exists, 'f' = regular file, 'd' = directory, 'L' = symlink
CREATE OR REPLACE FUNCTION test(
  p_username TEXT,
  p_flag TEXT,
  p_path TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  v_user_id INT;
  v_file RECORD;
  FILE_TYPE_MASK CONSTANT INT := 61440;
  DIR_TYPE CONSTANT INT := 16384;
  FILE_TYPE CONSTANT INT := 32768;
  SYMLINK_TYPE CONSTANT INT := 40960;
BEGIN
  SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  BEGIN
    SELECT * INTO v_file FROM filebypath(p_path) AS f;
  EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
  END;

  IF v_file.file_id IS NULL THEN
    RETURN FALSE;
  END IF;

  CASE p_flag
    WHEN 'e' THEN RETURN TRUE;
    WHEN 'f' THEN RETURN (v_file.mode & FILE_TYPE_MASK) = FILE_TYPE;
    WHEN 'd' THEN RETURN (v_file.mode & FILE_TYPE_MASK) = DIR_TYPE;
    WHEN 'L' THEN RETURN (v_file.mode & FILE_TYPE_MASK) = SYMLINK_TYPE;
    ELSE RAISE EXCEPTION 'Unknown test flag "%"', p_flag;
  END CASE;
END;
$$ LANGUAGE plpgsql;
