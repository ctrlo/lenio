-- Convert schema 'share/migrations/_source/deploy/28/001-auto.yml' to 'share/migrations/_source/deploy/29/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN parent_id integer NULL,
                   ADD INDEX ticket_idx_parent_id (parent_id),
                   ADD CONSTRAINT ticket_fk_parent_id FOREIGN KEY (parent_id) REFERENCES ticket (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

;

COMMIT;

