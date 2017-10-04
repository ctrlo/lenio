-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/9/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket DROP CONSTRAINT ticket_fk_site_id;

;
ALTER TABLE ticket DROP CONSTRAINT ticket_fk_task_id;

;
DROP INDEX ticket_idx_site_id;

;
DROP INDEX ticket_idx_task_id;

;
ALTER TABLE ticket DROP COLUMN task_id;

;
ALTER TABLE ticket DROP COLUMN site_id;

;

COMMIT;

