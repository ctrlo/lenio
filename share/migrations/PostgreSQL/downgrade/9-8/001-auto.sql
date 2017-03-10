-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/9/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/8/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE login DROP COLUMN only_mine;

;
ALTER TABLE ticket DROP CONSTRAINT ticket_fk_created_by;

;
DROP INDEX ticket_idx_created_by;

;
ALTER TABLE ticket DROP COLUMN created_by;

;

COMMIT;

