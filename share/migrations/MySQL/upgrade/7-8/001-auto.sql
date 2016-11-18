-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/7/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/8/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE invoice ADD COLUMN number text NULL;

;
ALTER TABLE ticket ADD COLUMN contractor_invoice text NULL;

;

COMMIT;

