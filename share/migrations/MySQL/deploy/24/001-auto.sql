-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Jan 29 10:23:39 2021
-- 
;
SET foreign_key_checks=0;
--
-- Table: `attach`
--
CREATE TABLE `attach` (
  `id` integer NOT NULL auto_increment,
  `name` text NOT NULL,
  `ticket_id` integer NOT NULL,
  `mimetype` text NOT NULL,
  INDEX `attach_idx_ticket_id` (`ticket_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `attach_fk_ticket_id` FOREIGN KEY (`ticket_id`) REFERENCES `ticket` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `audit`
--
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
--
-- Table: `check_done`
--
CREATE TABLE `check_done` (
  `id` integer NOT NULL auto_increment,
  `site_task_id` integer NOT NULL,
  `login_id` integer NOT NULL,
  `datetime` datetime NULL,
  `comment` text NULL,
  INDEX `check_done_idx_login_id` (`login_id`),
  INDEX `check_done_idx_site_task_id` (`site_task_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `check_done_fk_login_id` FOREIGN KEY (`login_id`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `check_done_fk_site_task_id` FOREIGN KEY (`site_task_id`) REFERENCES `site_task` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `check_item`
--
CREATE TABLE `check_item` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `task_id` integer NULL,
  `has_custom_options` smallint NOT NULL DEFAULT 0,
  INDEX `check_item_idx_task_id` (`task_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `check_item_fk_task_id` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `check_item_done`
--
CREATE TABLE `check_item_done` (
  `id` integer NOT NULL auto_increment,
  `check_item_id` integer NOT NULL,
  `check_done_id` integer NOT NULL,
  `status` smallint NULL,
  `status_custom` integer NULL,
  INDEX `check_item_done_idx_check_done_id` (`check_done_id`),
  INDEX `check_item_done_idx_check_item_id` (`check_item_id`),
  INDEX `check_item_done_idx_status_custom` (`status_custom`),
  PRIMARY KEY (`id`),
  UNIQUE `check_item_done_UNIQUE` (`check_item_id`, `check_done_id`),
  CONSTRAINT `check_item_done_fk_check_done_id` FOREIGN KEY (`check_done_id`) REFERENCES `check_done` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `check_item_done_fk_check_item_id` FOREIGN KEY (`check_item_id`) REFERENCES `check_item` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `check_item_done_fk_status_custom` FOREIGN KEY (`status_custom`) REFERENCES `check_item_option` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `check_item_option`
--
CREATE TABLE `check_item_option` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `check_item_id` integer NULL,
  `is_deleted` smallint NOT NULL DEFAULT 0,
  INDEX `check_item_option_idx_check_item_id` (`check_item_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `check_item_option_fk_check_item_id` FOREIGN KEY (`check_item_id`) REFERENCES `check_item` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `comment`
--
CREATE TABLE `comment` (
  `id` integer NOT NULL auto_increment,
  `text` text NULL,
  `login_id` integer NULL,
  `ticket_id` integer NOT NULL,
  `datetime` datetime NOT NULL,
  `admin_only` smallint NOT NULL DEFAULT 0,
  INDEX `comment_idx_login_id` (`login_id`),
  INDEX `comment_idx_ticket_id` (`ticket_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `comment_fk_login_id` FOREIGN KEY (`login_id`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `comment_fk_ticket_id` FOREIGN KEY (`ticket_id`) REFERENCES `ticket` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `contractor`
--
CREATE TABLE `contractor` (
  `id` integer NOT NULL auto_increment,
  `name` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `event`
--
CREATE TABLE `event` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `datefrom` datetime NULL,
  `dateto` datetime NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `event_org`
--
CREATE TABLE `event_org` (
  `id` integer NOT NULL auto_increment,
  `event_id` integer NULL,
  `org_id` integer NULL,
  INDEX `event_org_idx_event_id` (`event_id`),
  INDEX `event_org_idx_org_id` (`org_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `event_org_fk_event_id` FOREIGN KEY (`event_id`) REFERENCES `event` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `event_org_fk_org_id` FOREIGN KEY (`org_id`) REFERENCES `org` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `group`
--
CREATE TABLE `group` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `invoice`
--
CREATE TABLE `invoice` (
  `id` integer NOT NULL auto_increment,
  `number` text NULL,
  `description` text NULL,
  `ticket_id` integer NULL,
  `disbursements` integer NULL,
  `datetime` datetime NOT NULL,
  INDEX `invoice_idx_ticket_id` (`ticket_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `invoice_fk_ticket_id` FOREIGN KEY (`ticket_id`) REFERENCES `ticket` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `login`
--
CREATE TABLE `login` (
  `id` integer NOT NULL auto_increment,
  `username` varchar(128) NOT NULL,
  `email` varchar(128) NULL,
  `firstname` text NULL,
  `surname` text NULL,
  `password` varchar(128) NOT NULL,
  `is_admin` smallint NOT NULL DEFAULT 0,
  `pwdreset` varchar(32) NULL,
  `email_comment` smallint NOT NULL DEFAULT 0,
  `email_ticket` smallint NOT NULL DEFAULT 0,
  `only_mine` smallint NOT NULL DEFAULT 0,
  `deleted` datetime NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `login_notice`
--
CREATE TABLE `login_notice` (
  `id` integer NOT NULL auto_increment,
  `notice_id` integer NOT NULL,
  `login_id` integer NOT NULL,
  INDEX `login_notice_idx_login_id` (`login_id`),
  INDEX `login_notice_idx_notice_id` (`notice_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `login_notice_fk_login_id` FOREIGN KEY (`login_id`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `login_notice_fk_notice_id` FOREIGN KEY (`notice_id`) REFERENCES `notice` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `login_org`
--
CREATE TABLE `login_org` (
  `id` integer NOT NULL auto_increment,
  `login_id` integer NOT NULL,
  `org_id` integer NOT NULL,
  INDEX `login_org_idx_login_id` (`login_id`),
  INDEX `login_org_idx_org_id` (`org_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `login_org_fk_login_id` FOREIGN KEY (`login_id`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `login_org_fk_org_id` FOREIGN KEY (`org_id`) REFERENCES `org` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `login_permission`
--
CREATE TABLE `login_permission` (
  `id` integer NOT NULL auto_increment,
  `login_id` integer NOT NULL,
  `permission_id` integer NOT NULL,
  INDEX `login_permission_idx_login_id` (`login_id`),
  INDEX `login_permission_idx_permission_id` (`permission_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `login_permission_fk_login_id` FOREIGN KEY (`login_id`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `login_permission_fk_permission_id` FOREIGN KEY (`permission_id`) REFERENCES `permission` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `notice`
--
CREATE TABLE `notice` (
  `id` integer NOT NULL auto_increment,
  `text` text NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `org`
--
CREATE TABLE `org` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `address1` text NULL,
  `address2` text NULL,
  `town` text NULL,
  `postcode` text NULL,
  `case_number` text NULL,
  `fyfrom` date NULL,
  `created` datetime NULL,
  `deleted` datetime NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `permission`
--
CREATE TABLE `permission` (
  `id` integer NOT NULL auto_increment,
  `name` text NOT NULL,
  `description` text NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `site`
--
CREATE TABLE `site` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `org_id` integer NOT NULL,
  INDEX `site_idx_org_id` (`org_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `site_fk_org_id` FOREIGN KEY (`org_id`) REFERENCES `org` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `site_group`
--
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
--
-- Table: `site_task`
--
CREATE TABLE `site_task` (
  `id` integer NOT NULL auto_increment,
  `task_id` integer NULL,
  `site_id` integer NOT NULL,
  INDEX `site_task_idx_site_id` (`site_id`),
  INDEX `site_task_idx_task_id` (`task_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `site_task_fk_site_id` FOREIGN KEY (`site_id`) REFERENCES `site` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `site_task_fk_task_id` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `task`
--
CREATE TABLE `task` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `description` text NULL,
  `contractor_requirements` text NULL,
  `evidence_required` text NULL,
  `statutory` text NULL,
  `period_unit` varchar(45) NOT NULL,
  `period_qty` integer NOT NULL,
  `global` smallint NOT NULL DEFAULT 1,
  `site_check` smallint NOT NULL DEFAULT 0,
  `tasktype_id` integer NULL,
  `deleted` datetime NULL,
  INDEX `task_idx_tasktype_id` (`tasktype_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `task_fk_tasktype_id` FOREIGN KEY (`tasktype_id`) REFERENCES `tasktype` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
--
-- Table: `tasktype`
--
CREATE TABLE `tasktype` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `ticket`
--
CREATE TABLE `ticket` (
  `id` integer NOT NULL auto_increment,
  `name` text NULL,
  `description` text NULL,
  `created_by` integer NULL,
  `created_at` datetime NULL,
  `provisional` date NULL,
  `planned` date NULL,
  `completed` date NULL,
  `cancelled` date NULL,
  `contractor_id` integer NULL,
  `task_id` integer NULL,
  `site_id` integer NULL,
  `cost_planned` decimal(10, 2) NULL,
  `cost_actual` decimal(10, 2) NULL,
  `local_only` smallint NOT NULL DEFAULT 0,
  `report_received` smallint NOT NULL DEFAULT 0,
  `contractor_invoice` text NULL,
  `invoice_sent` smallint NOT NULL DEFAULT 0,
  `actionee` varchar(16) NULL,
  INDEX `ticket_idx_contractor_id` (`contractor_id`),
  INDEX `ticket_idx_created_by` (`created_by`),
  INDEX `ticket_idx_site_id` (`site_id`),
  INDEX `ticket_idx_task_id` (`task_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `ticket_fk_contractor_id` FOREIGN KEY (`contractor_id`) REFERENCES `contractor` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ticket_fk_created_by` FOREIGN KEY (`created_by`) REFERENCES `login` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ticket_fk_site_id` FOREIGN KEY (`site_id`) REFERENCES `site` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ticket_fk_task_id` FOREIGN KEY (`task_id`) REFERENCES `task` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;
SET foreign_key_checks=1;
