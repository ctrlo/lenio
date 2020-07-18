-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/21/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/20/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE org DROP COLUMN deleted;

;

COMMIT;

