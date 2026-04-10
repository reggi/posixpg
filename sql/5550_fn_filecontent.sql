CREATE OR REPLACE FUNCTION filecontent(
  p_content TEXT,
  p_blob TEXT,
  p_resolved_symbolic_ref INT,
  p_structured_data JSONB
)
RETURNS TEXT AS $$
DECLARE
  v_ref files%ROWTYPE;
BEGIN
  IF p_content IS NOT NULL THEN
    RETURN p_content;

  ELSIF p_structured_data IS NOT NULL THEN
    RETURN p_structured_data::TEXT;

  ELSIF p_resolved_symbolic_ref IS NOT NULL THEN
    SELECT * INTO v_ref FROM files WHERE file_id = p_resolved_symbolic_ref;
    RETURN filecontent(
      v_ref.content,
      v_ref.blob,
      v_ref.resolved_symbolic_ref,
      v_ref.structured_data
    );
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;
