CREATE TYPE modes AS (
  mode INT,
  type_bits INT,
  perm_bits INT,
  decimal_mode INT,
  decimal_type_bits INT,
  decimal_perm_bits INT,
  is_private BOOLEAN,
  is_directory BOOLEAN,
  is_symlink BOOLEAN,
  is_file BOOLEAN
);

-- Returns a modes composite type for a given mode integer
CREATE OR REPLACE FUNCTION allmodes(p_mode INT)
RETURNS modes AS $$
DECLARE
  v_type_bits INT;
  v_perm_bits INT;
  v_decimal_type_bits INT;
  v_decimal_perm_bits INT;
  v_decimal_mode INT;
  v_is_private BOOLEAN;
  v_is_directory BOOLEAN;
  v_is_symlink BOOLEAN;
  v_is_file BOOLEAN;
  v_result modes;
BEGIN
  -- Extract type bits (high 4 bits)
  v_type_bits := p_mode & 61440; -- 0o170000
  -- Extract permission bits (low 9 bits)
  v_perm_bits := p_mode & 511;   -- 0o777

  -- Convert to octal string using todecimal
  v_decimal_type_bits := todecimal(v_type_bits)::INT;
  v_decimal_perm_bits := todecimal(v_perm_bits)::INT;
  v_decimal_mode := todecimal(p_mode)::INT;

  -- Determine is_private: true if only owner and group have access, no public (other) access
  v_is_private := (v_perm_bits & 7 = 0); -- 0o007 is 'other' bits

  -- Determine type
  v_is_directory := (v_type_bits = 16384); -- 0o040000
  v_is_symlink := (v_type_bits = 40960);   -- 0o120000
  v_is_file := (v_type_bits = 32768);      -- 0o100000

  v_result := (
    p_mode,
    v_type_bits,
    v_perm_bits,
    v_decimal_mode,
    v_decimal_type_bits,
    v_decimal_perm_bits,
    v_is_private,
    v_is_directory,
    v_is_symlink,
    v_is_file
  );
  RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
