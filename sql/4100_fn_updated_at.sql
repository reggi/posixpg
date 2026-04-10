-- exports: updated_at

-- Function to update the 'updated_at' column automatically on record updates
CREATE OR REPLACE FUNCTION updated_at () RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';
