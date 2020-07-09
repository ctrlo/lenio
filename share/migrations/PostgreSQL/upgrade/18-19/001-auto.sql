-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/18/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/19/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE task ADD COLUMN contractor_requirements text;

;
ALTER TABLE task ADD COLUMN evidence_required text;

;
ALTER TABLE task ADD COLUMN statutory text;

;

COMMIT;

