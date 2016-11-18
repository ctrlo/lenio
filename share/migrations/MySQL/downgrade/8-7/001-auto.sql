-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/8/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/7/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE invoice DROP COLUMN number;

;
ALTER TABLE ticket DROP COLUMN contractor_invoice;

;

COMMIT;

