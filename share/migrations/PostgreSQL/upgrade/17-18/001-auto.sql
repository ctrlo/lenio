-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/17/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/18/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN created_at timestamp;

;

COMMIT;

