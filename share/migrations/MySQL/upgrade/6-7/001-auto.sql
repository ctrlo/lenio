-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/6/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/7/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `invoice` (
  `id` integer NOT NULL auto_increment,
  `description` text NULL,
  `ticket_id` integer NULL,
  `disbursements` integer NULL,
  `datetime` datetime NOT NULL,
  INDEX `invoice_idx_ticket_id` (`ticket_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `invoice_fk_ticket_id` FOREIGN KEY (`ticket_id`) REFERENCES `ticket` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;
ALTER TABLE org ADD COLUMN case_number text NULL;

;

COMMIT;

