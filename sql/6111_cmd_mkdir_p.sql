-- mkdir -p: create directory and all missing parents
CREATE OR REPLACE FUNCTION mkdir_p(p_username TEXT, abs_path TEXT, p_mode INT DEFAULT NULL)
RETURNS files AS $$
DECLARE
  path_parts TEXT[];
  i INT;
  current_path TEXT;
  result files%ROWTYPE;
BEGIN
  IF abs_path IS NULL OR abs_path = '' OR abs_path = '/' THEN
    RAISE EXCEPTION 'Invalid path';
  END IF;

  abs_path := trim(both '/' from abs_path);
  path_parts := string_to_array(abs_path, '/');

  -- Create each directory in the path if it doesn't exist
  FOR i IN 1..array_length(path_parts, 1) LOOP
    current_path := '/' || array_to_string(path_parts[1:i], '/');

    -- Check if this path segment exists
    BEGIN
      PERFORM filebypath(current_path);
      -- exists, continue
    EXCEPTION WHEN OTHERS THEN
      -- doesn't exist, create it
      result := mkdir(p_username, current_path, p_mode);
    END;
  END LOOP;

  -- Return the final (deepest) directory
  SELECT * INTO result FROM filebypath(abs_path);
  RETURN result;
END;
$$ LANGUAGE plpgsql;
