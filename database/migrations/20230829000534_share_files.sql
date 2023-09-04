-- +goose Up
-- +goose StatementBegin

CREATE TABLE IF NOT EXISTS teldrive.shared_files (
  id TEXT PRIMARY KEY NOT NULL DEFAULT teldrive.generate_uid(16),
  file_id TEXT NOT NULL,
  shared_with BIGINT,
  shared_by BIGINT NOT NULL,
  permission_level TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMP NOT NULL DEFAULT timezone('utc'::text, now()),
  FOREIGN KEY (file_id) REFERENCES teldrive.files(id),
  FOREIGN KEY (shared_with) REFERENCES teldrive.users(user_id),
  FOREIGN KEY (shared_by) REFERENCES teldrive.users(user_id),
  CONSTRAINT unique_token_file UNIQUE (shared_with, file_id)
);


CREATE OR REPLACE PROCEDURE teldrive.handle_shared_users(shared_by_param BIGINT,file_id_param TEXT,payload JSONB DEFAULT NULL,op TEXT DEFAULT NULL,perm_level TEXT DEFAULT NULL ) 
AS $$
DECLARE
    jsonb_object  JSONB;
    rec RECORD;
BEGIN

    SELECT * INTO rec FROM teldrive.files WHERE id = file_id_param;

    IF op = 'publicshare' THEN

    INSERT INTO teldrive.shared_files (file_id,shared_by,permission_level)
    VALUES (file_id_param, user_id_param,perm_level);

    ELSIF op = 'disableshare' THEN

    DELETE FROM teldrive.shared_files WHERE shared_by = shared_by_param AND file_id = file_id_param ;
    
    ELSIF op = 'modifyusers' THEN

    FOR jsonb_object IN SELECT * FROM jsonb_array_elements(payload)
    LOOP
      IF jsonb_object->>'operation' = 'add' THEN

      INSERT INTO teldrive.shared_files (file_id ,shared_by,shared_with,permission_level)
      VALUES (file_id_param, user_id_param, jsonb_object->>'userId'::BIGINT,jsonb_object->>'permission'::TEXT);
      
      ELSIF jsonb_object->>'operation' = 'remove' THEN
      DELETE FROM teldrive.shared_files WHERE shared_by = shared_by_param  AND shared_with = jsonb_object->>'userId'::BIGINT  AND file_id = file_id_param ;

      ELSE

      UPDATE teldrive.shared_files SET permission_level =  jsonb_object->>'permission'::TEXT   WHERE shared_by = shared_by_param  AND shared_with = jsonb_object->>'userId'::BIGINT  AND file_id = file_id_param ;
      
      END IF;

    END LOOP;

  END IF;
    
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE teldrive.handle_share_recursive(shared_by_param BIGINT,file_id_param TEXT,payload JSONB DEFAULT NULL,op TEXT DEFAULT NULL,perm_level TEXT DEFAULT NULL ) 
AS $$
DECLARE
    rec RECORD;
BEGIN

    FOR rec IN SELECT id, type FROM teldrive.files WHERE parent_id = file_id_param
    LOOP
	    IF rec.type = 'folder' THEN
      CALL teldrive.handle_share_recursive(shared_by_param,rec.id,payload,op,perm_level);

      END IF;
      
      CALL teldrive.handle_shared_users(shared_by_param,rec.id,payload,op,perm_level);

    END LOOP;
    CALL teldrive.handle_shared_users(shared_by_param,file_id_param,payload,op,perm_level);

END;
$$ LANGUAGE plpgsql;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TABLE IF EXISTS teldrive.shared_files;
DROP FUNCTION IF EXISTS teldrive.handle_shared_users;
DROP FUNCTION IF EXISTS teldrive.handle_share_recursive;
-- +goose StatementEnd
