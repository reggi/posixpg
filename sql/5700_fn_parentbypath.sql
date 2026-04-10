CREATE OR REPLACE FUNCTION parentbypath(abs_path TEXT)
RETURNS files AS $$
DECLARE
  parsed parsed_path;
  dirname_array TEXT[];
  result files%ROWTYPE;
BEGIN
  parsed := parsepath(abs_path);
  dirname_array := parsed.dirname_array;

  SELECT * INTO result FROM files WHERE path_array = dirname_array;

  IF NOT FOUND THEN
    RAISE EXCEPTION '%: No such file or directory', abs_path;
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql;
