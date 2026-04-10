CREATE TYPE pagination AS (
  "page" INT,
  "limit" INT,
  "has_next" BOOLEAN,
  "total_count" INT
);

CREATE TYPE directory AS (
  directory securefile_type,
  files securefile_type[],
  pagination pagination
);

CREATE OR REPLACE FUNCTION readfiles(
  p_username TEXT,
  p_path TEXT,
  p_limit INT DEFAULT 50,
  p_page INT DEFAULT 0,
  p_show_hidden BOOLEAN DEFAULT FALSE
) RETURNS directory AS $$
DECLARE
  v_user users%ROWTYPE;
  v_dir vfiles%ROWTYPE;
  v_dir_access securefile_type;
  v_count INT;
  v_rows securefile_type[];
BEGIN
  SELECT * INTO v_user FROM users WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;

  SELECT * INTO v_dir FROM filebypath(p_path) AS f;
  IF NOT FOUND THEN
    RAISE EXCEPTION '%: No such file or directory', p_path;
  END IF;

  IF NOT v_dir.is_directory THEN
    RAISE EXCEPTION 'Path "%" is not a directory', p_path;
  END IF;

  v_dir_access := securefile(v_user, v_dir);
  IF NOT (v_dir_access.read_perm AND v_dir_access.execute_perm) THEN
    RAISE EXCEPTION 'Permission denied on directory "%"', p_path;
  END IF;

  -- Count total matching entries
  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT securefile(v_user, vf) AS sf
    FROM vfiles vf
    WHERE vf.parent_id = v_dir.file_id
      AND (p_show_hidden OR NOT vf.is_hidden)
  ) AS sub(sf)
  WHERE (sf).read_perm;

  -- Get matching secure files as array
  SELECT array_agg(sf) INTO v_rows
  FROM (
    SELECT (securefile(v_user, vf)).*  -- expand fields
    FROM vfiles vf
    WHERE vf.parent_id = v_dir.file_id
      AND (p_show_hidden OR NOT vf.is_hidden)
    ORDER BY vf.name
    LIMIT p_limit OFFSET p_page * p_limit
  ) sf
  WHERE sf.read_perm;

  -- Return composite result
  RETURN (
    v_dir_access,
    COALESCE(v_rows, '{}'),
    ROW(p_page, p_limit, (p_page + 1) * p_limit < v_count, v_count)
  )::directory;
END;
$$ LANGUAGE plpgsql;
