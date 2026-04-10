-- select * from filebypath('/home/reggi');
CREATE OR REPLACE FUNCTION filebypath(abs_path TEXT)
RETURNS vfiles AS $$
DECLARE
  parsed parsed_path;
  v_path_array TEXT[];
  result vfiles%ROWTYPE;
BEGIN
  parsed := parsepath(abs_path);
  v_path_array := parsed.path_array;

  SELECT * INTO result FROM vfiles f WHERE f.path_array = v_path_array;

  IF NOT FOUND THEN
    RAISE EXCEPTION '%: No such file or directory', abs_path;
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql;
