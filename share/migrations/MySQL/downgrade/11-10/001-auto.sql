-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/11/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE site_task ADD COLUMN ticket_id integer NULL,
                      ADD INDEX site_task_idx_ticket_id (ticket_id),
                      ADD UNIQUE site_task_ticket_UNIQUE (site_id, task_id, ticket_id),
                      ADD UNIQUE ticket_id_UNIQUE (ticket_id),
                      ADD CONSTRAINT site_task_fk_ticket_id FOREIGN KEY (ticket_id) REFERENCES ticket (id) ON DELETE CASCADE ON UPDATE NO ACTION;

;

COMMIT;

