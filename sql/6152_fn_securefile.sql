CREATE TYPE securefile_type AS (
  -- file
  file_id INT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  "name" TEXT,
  parent_id INT,
  user_id INT,
  group_id INT,
  mode INT,
  "size" BIGINT,
  atime TIMESTAMPTZ,
  mtime TIMESTAMPTZ,
  structured_data JSONB,
  content TEXT,
  blob TEXT,
  symbolic_ref INT,
  is_directory BOOLEAN,
  p_id_n INT,
  hierarchy_mode INT,
  resolved_symbolic_ref INT,
  path_array TEXT[],
  resolved_symbolic_mode INT,
  resolved_symbolic_hierarchy_mode INT,
  -- vfile
  "path" TEXT,
  type_bits INT,
  perm_bits INT,
  decimal_mode INT,
  decimal_type_bits INT,
  decimal_perm_bits INT,
  is_symlink BOOLEAN,
  is_file BOOLEAN,

  hierarchy_type_bits INT,
  hierarchy_perm_bits INT,
  hierarchy_decimal_mode INT,
  hierarchy_decimal_type_bits INT,
  hierarchy_decimal_perm_bits INT,


  is_hidden BOOLEAN,
  "raw" TEXT,
  -- securefile
  read_perm boolean,
  write_perm boolean,
  execute_perm boolean,
  viewer_id INT,
  viewer_username TEXT
);

CREATE OR REPLACE FUNCTION securefile(
  p_user users,
  p_file vfiles
) RETURNS securefile_type AS $$
DECLARE
  a file_access;
  v_secure securefile_type;
BEGIN
  v_secure := p_file;

  a := auth(
    p_user.user_id,
    v_secure.mode,
    v_secure.user_id,
    v_secure.group_id,
    v_secure.parent_id,
    v_secure.resolved_symbolic_ref
  );

  v_secure.read_perm := a.read_perm;
  v_secure.write_perm := a.write_perm;
  v_secure.execute_perm := a.execute_perm;

  v_secure.viewer_id := p_user.user_id;
  v_secure.viewer_username := p_user.username;

  IF NOT a.read_perm THEN
    v_secure.structured_data := NULL;
    v_secure.content := NULL;
    v_secure.blob := NULL;
    v_secure.raw := NULL;
  END IF;

  RETURN v_secure;
END;
$$ LANGUAGE plpgsql;

-- this is used to test and query run securefile directly
CREATE OR REPLACE FUNCTION getsecurefile(
  p_username TEXT,
  p_path TEXT
) RETURNS securefile_type AS $$
DECLARE
  v_file vfiles%ROWTYPE;
  v_user users%ROWTYPE;
  v_secure securefile_type;
BEGIN
  SELECT * INTO v_file FROM filebypath(p_path) AS f;
  IF NOT FOUND THEN
    RAISE EXCEPTION '%: No such file or directory', abs_path;
  END IF;

  SELECT * INTO v_user FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  v_secure := securefile(v_user, v_file);

  RETURN v_secure;
END;
$$ LANGUAGE plpgsql;
