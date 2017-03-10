-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/8/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/9/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE login ADD COLUMN only_mine smallint NOT NULL DEFAULT 0;

;
ALTER TABLE ticket ADD COLUMN created_by integer NULL,
                   ADD INDEX ticket_idx_created_by (created_by),
                   ADD CONSTRAINT ticket_fk_created_by FOREIGN KEY (created_by) REFERENCES login (id) ON DELETE NO ACTION ON UPDATE NO ACTION;

;

COMMIT;

