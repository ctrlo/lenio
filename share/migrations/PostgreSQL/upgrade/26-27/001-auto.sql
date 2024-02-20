-- Convert schema 'share/migrations/_source/deploy/26/001-auto.yml' to 'share/migrations/_source/deploy/27/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE task ADD COLUMN bespoke smallint DEFAULT 0 NOT NULL;

;

COMMIT;

