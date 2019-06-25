-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/15/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/14/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE attach ADD COLUMN content bytea NOT NULL;

;

COMMIT;

