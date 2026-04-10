-- exports: octal

CREATE OR REPLACE FUNCTION octal(input ANYELEMENT)
RETURNS INT AS $$
DECLARE
  str TEXT := input::TEXT;
  result INT := 0;
  i INT := 1;
  len INT := length(str);
  digit INT;
BEGIN
  WHILE i <= len LOOP
    digit := cast(substr(str, i, 1) AS INT);
    IF digit < 0 OR digit > 7 THEN
      RAISE EXCEPTION 'Invalid octal digit: %', digit;
    END IF;
    result := result * 8 + digit;
    i := i + 1;
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
