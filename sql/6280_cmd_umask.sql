-- umask: get or set the file creation mask for the system
-- When creating files/dirs, actual_mode = requested_mode & ~umask
CREATE OR REPLACE FUNCTION umask(p_mask INT DEFAULT NULL)
RETURNS INT AS $$
DECLARE
  v_current INT;
BEGIN
  IF p_mask IS NOT NULL THEN
    -- Set umask
    INSERT INTO env (key, int) VALUES ('UMASK', octal(p_mask))
      ON CONFLICT (key) DO UPDATE SET int = octal(p_mask);
    RETURN p_mask;
  ELSE
    -- Get umask
    SELECT int INTO v_current FROM env WHERE key = 'UMASK';
    IF NOT FOUND THEN
      RETURN 22; -- default umask 022
    END IF;
    RETURN todecimal(v_current);
  END IF;
END;
$$ LANGUAGE plpgsql;
