-- Convert schema 'share/migrations/_source/deploy/27/001-auto.yml' to 'share/migrations/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE contractor ADD COLUMN deleted datetime NULL;

;

COMMIT;

