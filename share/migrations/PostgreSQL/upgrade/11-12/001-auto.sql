-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/11/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/12/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE task ADD COLUMN deleted timestamp;

;

COMMIT;

