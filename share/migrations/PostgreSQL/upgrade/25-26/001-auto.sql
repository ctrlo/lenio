-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/25/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/26/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE login ADD COLUMN lastfail timestamp;

;
ALTER TABLE login ADD COLUMN failcount integer DEFAULT 0 NOT NULL;

;

COMMIT;

