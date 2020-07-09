-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/19/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/18/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE task DROP COLUMN contractor_requirements;

;
ALTER TABLE task DROP COLUMN evidence_required;

;
ALTER TABLE task DROP COLUMN statutory;

;

COMMIT;

