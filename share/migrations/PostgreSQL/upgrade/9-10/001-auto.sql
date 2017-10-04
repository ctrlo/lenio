-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/9/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN task_id integer;

;
ALTER TABLE ticket ADD COLUMN site_id integer;

;
CREATE INDEX ticket_idx_site_id on ticket (site_id);

;
CREATE INDEX ticket_idx_task_id on ticket (task_id);

;
ALTER TABLE ticket ADD CONSTRAINT ticket_fk_site_id FOREIGN KEY (site_id)
  REFERENCES site (id) ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE ticket ADD CONSTRAINT ticket_fk_task_id FOREIGN KEY (task_id)
  REFERENCES task (id) ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

