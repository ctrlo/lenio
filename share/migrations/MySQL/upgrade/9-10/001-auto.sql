-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/9/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN task_id integer NULL,
                   ADD COLUMN site_id integer NULL,
                   ADD INDEX ticket_idx_site_id (site_id),
                   ADD INDEX ticket_idx_task_id (task_id),
                   ADD CONSTRAINT ticket_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE NO ACTION ON UPDATE NO ACTION,
                   ADD CONSTRAINT ticket_fk_task_id FOREIGN KEY (task_id) REFERENCES task (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

;

COMMIT;

