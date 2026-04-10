CREATE OR REPLACE FUNCTION homeset(p_path TEXT)
RETURNS VOID AS $$
DECLARE
  p_file_id int;
  superuser_name TEXT;
  created_dir files;
  existing_file vfiles%ROWTYPE;
BEGIN
  -- step 1: get the superuser (assuming username 'root')
  SELECT username INTO superuser_name FROM users WHERE superuser = true LIMIT 1;

  -- step 2: check if the path exists using filebypath
  BEGIN
    existing_file := filebypath(p_path);
    p_file_id := existing_file.file_id;
  EXCEPTION WHEN OTHERS THEN
    -- If not found, create it using mkdir (755 for system dirs like /home)
    created_dir := mkdir(superuser_name, p_path, 755);
    p_file_id := created_dir.file_id;
  END;

  -- step 3: upsert the DEFAULT_HOME_DIR key to the file_id of the path
  INSERT INTO env (key, file_id)
    VALUES ('DEFAULT_HOME_DIR', p_file_id)
    ON CONFLICT (key) DO UPDATE SET file_id = EXCLUDED.file_id;
END;
$$ LANGUAGE plpgsql;

