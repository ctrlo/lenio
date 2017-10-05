-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/11/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE site_task DROP CONSTRAINT site_task_ticket_UNIQUE;

;
ALTER TABLE site_task DROP CONSTRAINT ticket_id_UNIQUE;

;
ALTER TABLE site_task DROP CONSTRAINT site_task_fk_ticket_id;

;
DROP INDEX site_task_idx_ticket_id;

;
ALTER TABLE site_task DROP COLUMN ticket_id;

;

COMMIT;

