-- Create a composite type for parsed path
CREATE TYPE parsed_path AS (
  "name" TEXT,
  "dirname_array" TEXT[],
  "path_array" TEXT[]
);

CREATE OR REPLACE FUNCTION parsepath(abs_path TEXT)
RETURNS parsed_path AS $$
DECLARE
  path_parts TEXT[];
  resolved TEXT[];
  parent_parts TEXT[];
  base TEXT;
  result parsed_path;
  part TEXT;
BEGIN
  IF abs_path IS NULL OR abs_path = '' OR abs_path = '/' THEN
    RAISE EXCEPTION 'Invalid or root path not supported';
  END IF;
  
  abs_path := trim(both '/' from abs_path);
  path_parts := string_to_array(abs_path, '/');

  -- Resolve . and .. components
  resolved := ARRAY[]::TEXT[];
  FOREACH part IN ARRAY path_parts LOOP
    IF part = '.' OR part = '' THEN
      CONTINUE;
    ELSIF part = '..' THEN
      IF array_length(resolved, 1) IS NOT NULL AND array_length(resolved, 1) > 0 THEN
        resolved := resolved[1:array_upper(resolved, 1) - 1];
      END IF;
    ELSE
      resolved := resolved || part;
    END IF;
  END LOOP;

  IF array_length(resolved, 1) IS NULL OR array_length(resolved, 1) < 1 THEN
    RAISE EXCEPTION 'Path resolves to root, not supported';
  END IF;

  base := resolved[array_upper(resolved, 1)];
  parent_parts := resolved[1:array_upper(resolved, 1) - 1];

  result.name := base;
  result.dirname_array := parent_parts;
  result.path_array := resolved;

  RETURN result;
END;
$$ LANGUAGE plpgsql;
