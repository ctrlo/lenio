-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/6/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/5/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE org DROP COLUMN address1,
                DROP COLUMN address2,
                DROP COLUMN town,
                DROP COLUMN postcode,
                DROP COLUMN created;

;

COMMIT;

