-- Change file owner (superuser only, matching Unix chown)
CREATE OR REPLACE FUNCTION chown(
  p_username TEXT,
  p_new_owner TEXT,
  p_path TEXT
) RETURNS VOID AS $$
DECLARE
  v_user_id INT;
  v_superuser BOOLEAN;
  v_file files%ROWTYPE;
  v_new_owner_id INT;
BEGIN
  -- Resolve acting user
  SELECT user_id, superuser INTO v_user_id, v_superuser FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  -- Only superuser can chown
  IF NOT v_superuser THEN
    RAISE EXCEPTION 'Permission denied: only superuser can change ownership';
  END IF;

  -- Get file
  v_file := filebypath(p_path);
  IF v_file.file_id IS NULL THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  -- Resolve new owner
  SELECT user_id INTO v_new_owner_id FROM users WHERE username = p_new_owner;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_new_owner;
  END IF;

  -- Change ownership
  UPDATE files SET user_id = v_new_owner_id WHERE file_id = v_file.file_id;
END;
$$ LANGUAGE plpgsql VOLATILE;
