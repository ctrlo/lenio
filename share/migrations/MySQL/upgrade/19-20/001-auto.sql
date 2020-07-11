-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/19/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/20/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `group` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

;
CREATE TABLE `site_group` (
  `id` integer NOT NULL auto_increment,
  `site_id` integer NOT NULL,
  `group_id` integer NOT NULL,
  INDEX `site_group_idx_group_id` (`group_id`),
  INDEX `site_group_idx_site_id` (`site_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `site_group_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `group` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `site_group_fk_site_id` FOREIGN KEY (`site_id`) REFERENCES `site` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;

COMMIT;

