-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/14/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/13/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE check_item DROP COLUMN has_custom_options;

;
ALTER TABLE check_item_done DROP CONSTRAINT check_item_done_fk_status_custom;

;
DROP INDEX check_item_done_idx_status_custom;

;
ALTER TABLE check_item_done DROP COLUMN status_custom;

;
DROP TABLE check_item_option CASCADE;

;

COMMIT;

