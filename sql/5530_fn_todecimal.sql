CREATE OR REPLACE FUNCTION todecimal(n INT) RETURNS INT AS $$
DECLARE
  result INT := 0;
  multiplier INT := 1;
BEGIN
  IF n = 0 THEN
    RETURN 0;
  END IF;

  WHILE n > 0 LOOP
    result := result + (n % 8) * multiplier;
    n := n / 8;
    multiplier := multiplier * 10;
  END LOOP;

  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
