-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/5/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/6/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE org ADD COLUMN address1 text NULL,
                ADD COLUMN address2 text NULL,
                ADD COLUMN town text NULL,
                ADD COLUMN postcode text NULL,
                ADD COLUMN created datetime NULL;

;

COMMIT;

