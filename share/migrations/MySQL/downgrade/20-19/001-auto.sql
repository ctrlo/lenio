-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/20/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/19/001-auto.yml':;

;
BEGIN;

;
DROP TABLE group;

;
ALTER TABLE site_group DROP FOREIGN KEY site_group_fk_group_id,
                       DROP FOREIGN KEY site_group_fk_site_id;

;
DROP TABLE site_group;

;

COMMIT;

