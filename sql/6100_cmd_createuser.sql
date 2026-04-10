-- Variables passed to the procedure:
-- $1: username (TEXT) - The username of the new user.
-- $2: password_hash (TEXT) - The hashed password of the new user.
-- $3: create_dir (BOOLEAN) - Whether to create the home directory for the user.
-- $4: superuser (BOOLEAN) - Whether the user is a superuser.

CREATE TYPE createuser_result AS (
  "user" users,
  "group" groups,
  "home" files
);

CREATE OR REPLACE FUNCTION createuser(
  username TEXT,
  password_hash TEXT,
  create_dir BOOLEAN DEFAULT TRUE,
  superuser BOOLEAN DEFAULT FALSE
)
RETURNS createuser_result AS $$
DECLARE
  user_id INT;
  group_id INT;
  dir_mode INT;
  home_dir_id INT;
  created_user users%ROWTYPE;
  created_group groups%ROWTYPE;
  created_file files%ROWTYPE;
  result createuser_result;
BEGIN
  -- Step 1: Create a user
  INSERT INTO users (username, password_hash, superuser)
  VALUES (username, password_hash, superuser)
  RETURNING * INTO created_user;
  user_id := created_user.user_id;

  -- Step 2: Create a group for the user
  INSERT INTO groups ("group")
  VALUES (username)
  RETURNING * INTO created_group;
  group_id := created_group.group_id;

  -- Step 3: Assign the user to the group
  INSERT INTO user_groups (user_id, group_id)
  VALUES (user_id, group_id);

  -- Step 4: Optionally create home directory
  IF create_dir THEN
    SELECT int INTO dir_mode FROM env WHERE key = 'DEFAULT_DIR_MODE';
    dir_mode := dir_mode | 16384;
    IF dir_mode IS NULL THEN
      RAISE EXCEPTION 'DEFAULT_DIR_MODE missing or invalid';
    END IF;
    SELECT file_id INTO home_dir_id FROM env WHERE key = 'DEFAULT_HOME_DIR';
    IF home_dir_id IS NULL THEN
      RAISE EXCEPTION 'DEFAULT_HOME_DIR missing or invalid';
    END IF;
    INSERT INTO files (name, parent_id, user_id, group_id, mode, size, atime, mtime, is_directory, hierarchy_mode)
    VALUES (username, home_dir_id, user_id, group_id, dir_mode, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, TRUE, dir_mode)
    RETURNING * INTO created_file;
    UPDATE users AS u
    SET home_file_id = created_file.file_id
    WHERE u.user_id = created_user.user_id;
    result := (created_user, created_group, created_file);
  ELSE
    result := (created_user, created_group, NULL);
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql;
