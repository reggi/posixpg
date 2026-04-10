CREATE OR REPLACE FUNCTION mkgroup(groupname TEXT)
RETURNS INTEGER AS $$
DECLARE
    new_group_id INTEGER;
BEGIN
    INSERT INTO groups ("group") VALUES (groupname)
    RETURNING group_id INTO new_group_id;
    RETURN new_group_id;
EXCEPTION WHEN unique_violation THEN
    -- If group already exists, return its id
    SELECT group_id INTO new_group_id FROM groups WHERE "group" = groupname;
    RETURN new_group_id;
END;
$$ LANGUAGE plpgsql;
