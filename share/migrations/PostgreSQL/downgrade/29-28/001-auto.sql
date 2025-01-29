-- Convert schema 'share/migrations/_source/deploy/29/001-auto.yml' to 'share/migrations/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket DROP CONSTRAINT ticket_fk_parent_id;

;
DROP INDEX ticket_idx_parent_id;

;
ALTER TABLE ticket DROP COLUMN parent_id;

;

COMMIT;

