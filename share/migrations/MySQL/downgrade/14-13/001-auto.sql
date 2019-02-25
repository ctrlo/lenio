-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/14/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/13/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE check_item DROP COLUMN has_custom_options;

;
ALTER TABLE check_item_done DROP FOREIGN KEY check_item_done_fk_status_custom,
                            DROP INDEX check_item_done_idx_status_custom,
                            DROP COLUMN status_custom;

;
ALTER TABLE check_item_option DROP FOREIGN KEY check_item_option_fk_check_item_id;

;
DROP TABLE check_item_option;

;

COMMIT;

