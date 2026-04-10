CREATE OR REPLACE VIEW vfiles AS
SELECT
  f.*,
  '/' || array_to_string(f.path_array, '/') AS path,
  (f.mode & 61440)          AS type_bits,
  (f.mode & 511)            AS perm_bits,
  todecimal(f.mode)         AS decimal_mode,
  todecimal(f.mode & 61440) AS decimal_type_bits,
  todecimal(f.mode & 511)   AS decimal_perm_bits,
  (f.mode & 61440 = 40960)  AS is_symlink,
  (f.mode & 61440 = 32768)  AS is_file,
  (f.hierarchy_mode & 61440)          AS hierarchy_type_bits,
  (f.hierarchy_mode & 511)            AS hierarchy_perm_bits,
  todecimal(f.hierarchy_mode)         AS hierarchy_decimal_mode,
  todecimal(f.hierarchy_mode & 61440) AS hierarchy_decimal_type_bits,
  todecimal(f.hierarchy_mode & 511)   AS hierarchy_decimal_perm_bits,
  (left(f.name, 1) = '.')   AS is_hidden,
  CASE 
    WHEN f.is_directory = FALSE THEN filecontent(
      f.content,
      f.blob,
      f.resolved_symbolic_ref,
      f.structured_data
    )
    ELSE NULL
  END AS "raw"
FROM files f;
