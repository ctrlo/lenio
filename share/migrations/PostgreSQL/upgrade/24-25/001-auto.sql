-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/24/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/25/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE login ALTER COLUMN password DROP NOT NULL;

;

COMMIT;

