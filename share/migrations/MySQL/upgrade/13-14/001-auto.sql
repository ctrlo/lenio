-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/13/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/14/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `check_item_option` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `check_item_id` integer NULL,
  `is_deleted` smallint NOT NULL DEFAULT 0,
  INDEX `check_item_option_idx_check_item_id` (`check_item_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `check_item_option_fk_check_item_id` FOREIGN KEY (`check_item_id`) REFERENCES `check_item` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;
ALTER TABLE check_item ADD COLUMN has_custom_options smallint NOT NULL DEFAULT 0;

;
ALTER TABLE check_item_done ADD COLUMN status_custom integer NULL,
                            ADD INDEX check_item_done_idx_status_custom (status_custom),
                            ADD CONSTRAINT check_item_done_fk_status_custom FOREIGN KEY (status_custom) REFERENCES check_item_option (id) ON DELETE CASCADE ON UPDATE NO ACTION;

;

COMMIT;

