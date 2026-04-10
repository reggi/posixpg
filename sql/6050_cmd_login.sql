CREATE OR REPLACE FUNCTION login(
  p_username TEXT,
  p_password_with_pepper TEXT
) RETURNS TABLE(user_id INT, username TEXT, superuser BOOLEAN) AS $$
BEGIN
  RETURN QUERY
    SELECT u.user_id, u.username, u.superuser
    FROM users u
    WHERE u.username = p_username
      AND crypt(p_password_with_pepper, u.password_hash) = u.password_hash;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Login failed for user "%"', p_username;
  END IF;
END;
$$ LANGUAGE plpgsql;
