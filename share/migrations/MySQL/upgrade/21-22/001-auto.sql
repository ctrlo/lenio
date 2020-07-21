-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/21/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/22/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN cancelled date NULL;

;

COMMIT;

