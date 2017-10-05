-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/11/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE site_task DROP INDEX site_task_ticket_UNIQUE,
                      DROP INDEX ticket_id_UNIQUE,
                      DROP FOREIGN KEY site_task_fk_ticket_id,
                      DROP INDEX site_task_idx_ticket_id,
                      DROP COLUMN ticket_id;

;

COMMIT;

