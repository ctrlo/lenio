-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/11/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE site_task ADD COLUMN ticket_id integer;

;
CREATE INDEX site_task_idx_ticket_id on site_task (ticket_id);

;
ALTER TABLE site_task ADD CONSTRAINT site_task_ticket_UNIQUE UNIQUE (site_id, task_id, ticket_id);

;
ALTER TABLE site_task ADD CONSTRAINT ticket_id_UNIQUE UNIQUE (ticket_id);

;
ALTER TABLE site_task ADD CONSTRAINT site_task_fk_ticket_id FOREIGN KEY (ticket_id)
  REFERENCES ticket (id) ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

