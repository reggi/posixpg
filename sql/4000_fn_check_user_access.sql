-- Corrected function to avoid ambiguity
CREATE OR REPLACE FUNCTION check_user_access(
  user_id INT,
  file_mode INT,
  file_hierarchy_mode INT,
  file_owner_id INT,
  file_group_id INT,
  file_type TEXT, -- Added parameter to specify file type
  symlink_ref_mode INT DEFAULT NULL, -- Added for symlink handling
  symlink_ref_hierarchy_mode INT DEFAULT NULL, -- Added for symlink handling
  symlink_ref_parent_mode INT DEFAULT NULL -- Added for symlink handling
) RETURNS JSONB AS $$
DECLARE
  access JSONB;
BEGIN
  SELECT jsonb_build_object(
    'read', CASE
      WHEN file_type = 'directory' THEN -- Directory access
        CASE
          WHEN file_owner_id = check_user_access.user_id THEN -- OWNER access
            (file_mode & 256) > 0 AND (file_hierarchy_mode & 256) > 0 -- OWNER read/execute
          WHEN EXISTS (
            SELECT 1 FROM user_groups ug WHERE ug.user_id = check_user_access.user_id AND ug.group_id = file_group_id
          ) THEN -- GROUP access
            (file_mode & 32) > 0 AND (file_hierarchy_mode & 32) > 0 -- GROUP read/execute
          ELSE -- OTHER access
            (file_mode & 4) > 0 AND (file_hierarchy_mode & 4) > 0 -- OTHER read/execute
        END
      WHEN file_type = 'file' THEN -- File access
        CASE
          WHEN file_owner_id = check_user_access.user_id THEN -- OWNER access
            (file_mode & 256) > 0 -- OWNER read
          WHEN EXISTS (
            SELECT 1 FROM user_groups ug WHERE ug.user_id = check_user_access.user_id AND ug.group_id = file_group_id
          ) THEN -- GROUP access
            (file_mode & 32) > 0 -- GROUP read
          ELSE -- OTHER access
            (file_mode & 4) > 0 -- OTHER read
        END
      WHEN file_type = 'symlink_dir' THEN -- Symlink to directory
        CASE
          WHEN symlink_ref_mode IS NOT NULL AND symlink_ref_hierarchy_mode IS NOT NULL THEN
            (symlink_ref_mode & 256) > 0 AND (symlink_ref_hierarchy_mode & 256) > 0 -- OWNER read/execute
          ELSE
            false
        END
      WHEN file_type = 'symlink_file' THEN -- Symlink to file
        CASE
          WHEN symlink_ref_mode IS NOT NULL AND symlink_ref_parent_mode IS NOT NULL THEN
            (symlink_ref_mode & 256) > 0 -- OWNER read
          ELSE
            false
        END
      ELSE
        false
    END,
    'write', CASE
      WHEN file_type = 'directory' OR file_type = 'file' THEN -- Write access for directories and files
        CASE
          WHEN file_owner_id = check_user_access.user_id THEN -- OWNER access
            (file_mode & 128) > 0 -- OWNER write
          WHEN EXISTS (
            SELECT 1 FROM user_groups ug WHERE ug.user_id = check_user_access.user_id AND ug.group_id = file_group_id
          ) THEN -- GROUP access
            (file_mode & 16) > 0 -- GROUP write
          ELSE -- OTHER access
            (file_mode & 2) > 0 -- OTHER write
        END
      ELSE
        false
    END,
    'execute', CASE
      WHEN file_type = 'directory' THEN -- Execute access for directories
        CASE
          WHEN file_owner_id = check_user_access.user_id THEN -- OWNER access
            (file_hierarchy_mode & 256) > 0 -- OWNER execute
          WHEN EXISTS (
            SELECT 1 FROM user_groups ug WHERE ug.user_id = check_user_access.user_id AND ug.group_id = file_group_id
          ) THEN -- GROUP access
            (file_hierarchy_mode & 32) > 0 -- GROUP execute
          ELSE -- OTHER access
            (file_hierarchy_mode & 4) > 0 -- OTHER execute
        END
      WHEN file_type = 'symlink_dir' THEN -- Execute access for symlink to directory
        CASE
          WHEN symlink_ref_hierarchy_mode IS NOT NULL THEN
            (symlink_ref_hierarchy_mode & 256) > 0 -- OWNER execute
          ELSE
            false
        END
      ELSE
        false
    END
  ) INTO access;

  RETURN access;
END;
$$ LANGUAGE plpgsql;
