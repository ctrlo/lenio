-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/2/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/3/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE site_task DROP CONSTRAINT site_task_fk_ticket_id;

;
ALTER TABLE site_task ADD CONSTRAINT site_task_fk_ticket_id FOREIGN KEY (ticket_id)
  REFERENCES ticket (id) ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

