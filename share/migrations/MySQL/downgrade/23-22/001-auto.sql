-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/23/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/22/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE comment DROP COLUMN admin_only;

;

COMMIT;

