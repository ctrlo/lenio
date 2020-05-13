-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/17/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/16/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE audit DROP FOREIGN KEY audit_fk_login_id;

;
DROP TABLE audit;

;

COMMIT;

