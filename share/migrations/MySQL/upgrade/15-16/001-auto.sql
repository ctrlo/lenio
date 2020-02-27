-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/15/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/16/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN provisional date NULL;

;

COMMIT;

