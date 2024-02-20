-- Convert schema 'share/migrations/_source/deploy/27/001-auto.yml' to 'share/migrations/_source/deploy/26/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE task DROP COLUMN bespoke;

;

COMMIT;

