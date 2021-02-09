-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/26/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/25/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE login DROP COLUMN lastfail,
                  DROP COLUMN failcount;

;

COMMIT;

