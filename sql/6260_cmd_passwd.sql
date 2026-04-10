-- Change user password
CREATE OR REPLACE FUNCTION passwd(
  p_username TEXT,
  p_new_password_hash TEXT
) RETURNS VOID AS $$
BEGIN
  UPDATE users SET password_hash = p_new_password_hash WHERE username = p_username;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User "%" not found', p_username;
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;
