-- Convert schema 'share/migrations/_source/deploy/26/001-auto.yml' to 'share/migrations/_source/deploy/27/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE task ADD COLUMN bespoke smallint NOT NULL DEFAULT 0;

;

COMMIT;

