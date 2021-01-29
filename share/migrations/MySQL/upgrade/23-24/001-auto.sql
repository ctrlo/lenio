-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/23/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/24/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE login CHANGE COLUMN email email varchar(128) NULL;

;

COMMIT;

