-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/12/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/13/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN actionee varchar(16) NULL;

;

COMMIT;

