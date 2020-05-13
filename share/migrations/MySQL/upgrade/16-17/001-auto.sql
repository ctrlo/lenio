-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/16/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/17/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `audit` (
  `id` integer NOT NULL auto_increment,
  `login_id` integer NULL,
  `type` varchar(45) NULL,
  `datetime` datetime NULL,
  `method` varchar(45) NULL,
  `url` text NULL,
  `description` text NULL,
  INDEX `audit_idx_login_id` (`login_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `audit_fk_login_id` FOREIGN KEY (`login_id`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;

COMMIT;

