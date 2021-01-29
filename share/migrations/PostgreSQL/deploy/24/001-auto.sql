-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Fri Jan 29 10:23:40 2021
-- 
;
--
-- Table: attach
--
CREATE TABLE "attach" (
  "id" serial NOT NULL,
  "name" text NOT NULL,
  "ticket_id" integer NOT NULL,
  "mimetype" text NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "attach_idx_ticket_id" on "attach" ("ticket_id");

;
--
-- Table: audit
--
CREATE TABLE "audit" (
  "id" serial NOT NULL,
  "login_id" integer,
  "type" character varying(45),
  "datetime" timestamp,
  "method" character varying(45),
  "url" text,
  "description" text,
  PRIMARY KEY ("id")
);
CREATE INDEX "audit_idx_login_id" on "audit" ("login_id");

;
--
-- Table: check_done
--
CREATE TABLE "check_done" (
  "id" serial NOT NULL,
  "site_task_id" integer NOT NULL,
  "login_id" integer NOT NULL,
  "datetime" timestamp,
  "comment" text,
  PRIMARY KEY ("id")
);
CREATE INDEX "check_done_idx_login_id" on "check_done" ("login_id");
CREATE INDEX "check_done_idx_site_task_id" on "check_done" ("site_task_id");

;
--
-- Table: check_item
--
CREATE TABLE "check_item" (
  "id" serial NOT NULL,
  "name" text,
  "task_id" integer,
  "has_custom_options" smallint DEFAULT 0 NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "check_item_idx_task_id" on "check_item" ("task_id");

;
--
-- Table: check_item_done
--
CREATE TABLE "check_item_done" (
  "id" serial NOT NULL,
  "check_item_id" integer NOT NULL,
  "check_done_id" integer NOT NULL,
  "status" smallint,
  "status_custom" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "check_item_done_UNIQUE" UNIQUE ("check_item_id", "check_done_id")
);
CREATE INDEX "check_item_done_idx_check_done_id" on "check_item_done" ("check_done_id");
CREATE INDEX "check_item_done_idx_check_item_id" on "check_item_done" ("check_item_id");
CREATE INDEX "check_item_done_idx_status_custom" on "check_item_done" ("status_custom");

;
--
-- Table: check_item_option
--
CREATE TABLE "check_item_option" (
  "id" serial NOT NULL,
  "name" text,
  "check_item_id" integer,
  "is_deleted" smallint DEFAULT 0 NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "check_item_option_idx_check_item_id" on "check_item_option" ("check_item_id");

;
--
-- Table: comment
--
CREATE TABLE "comment" (
  "id" serial NOT NULL,
  "text" text,
  "login_id" integer,
  "ticket_id" integer NOT NULL,
  "datetime" timestamp NOT NULL,
  "admin_only" smallint DEFAULT 0 NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "comment_idx_login_id" on "comment" ("login_id");
CREATE INDEX "comment_idx_ticket_id" on "comment" ("ticket_id");

;
--
-- Table: contractor
--
CREATE TABLE "contractor" (
  "id" serial NOT NULL,
  "name" text NOT NULL,
  PRIMARY KEY ("id")
);

;
--
-- Table: event
--
CREATE TABLE "event" (
  "id" serial NOT NULL,
  "name" text,
  "datefrom" timestamp,
  "dateto" timestamp,
  PRIMARY KEY ("id")
);

;
--
-- Table: event_org
--
CREATE TABLE "event_org" (
  "id" serial NOT NULL,
  "event_id" integer,
  "org_id" integer,
  PRIMARY KEY ("id")
);
CREATE INDEX "event_org_idx_event_id" on "event_org" ("event_id");
CREATE INDEX "event_org_idx_org_id" on "event_org" ("org_id");

;
--
-- Table: group
--
CREATE TABLE "group" (
  "id" serial NOT NULL,
  "name" text,
  PRIMARY KEY ("id")
);

;
--
-- Table: invoice
--
CREATE TABLE "invoice" (
  "id" serial NOT NULL,
  "number" text,
  "description" text,
  "ticket_id" integer,
  "disbursements" integer,
  "datetime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "invoice_idx_ticket_id" on "invoice" ("ticket_id");

;
--
-- Table: login
--
CREATE TABLE "login" (
  "id" serial NOT NULL,
  "username" character varying(128) NOT NULL,
  "email" character varying(128),
  "firstname" text,
  "surname" text,
  "password" character varying(128) NOT NULL,
  "is_admin" smallint DEFAULT 0 NOT NULL,
  "pwdreset" character varying(32),
  "email_comment" smallint DEFAULT 0 NOT NULL,
  "email_ticket" smallint DEFAULT 0 NOT NULL,
  "only_mine" smallint DEFAULT 0 NOT NULL,
  "deleted" timestamp,
  PRIMARY KEY ("id")
);

;
--
-- Table: login_notice
--
CREATE TABLE "login_notice" (
  "id" serial NOT NULL,
  "notice_id" integer NOT NULL,
  "login_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "login_notice_idx_login_id" on "login_notice" ("login_id");
CREATE INDEX "login_notice_idx_notice_id" on "login_notice" ("notice_id");

;
--
-- Table: login_org
--
CREATE TABLE "login_org" (
  "id" serial NOT NULL,
  "login_id" integer NOT NULL,
  "org_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "login_org_idx_login_id" on "login_org" ("login_id");
CREATE INDEX "login_org_idx_org_id" on "login_org" ("org_id");

;
--
-- Table: login_permission
--
CREATE TABLE "login_permission" (
  "id" serial NOT NULL,
  "login_id" integer NOT NULL,
  "permission_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "login_permission_idx_login_id" on "login_permission" ("login_id");
CREATE INDEX "login_permission_idx_permission_id" on "login_permission" ("permission_id");

;
--
-- Table: notice
--
CREATE TABLE "notice" (
  "id" serial NOT NULL,
  "text" text,
  PRIMARY KEY ("id")
);

;
--
-- Table: org
--
CREATE TABLE "org" (
  "id" serial NOT NULL,
  "name" text,
  "address1" text,
  "address2" text,
  "town" text,
  "postcode" text,
  "case_number" text,
  "fyfrom" date,
  "created" timestamp,
  "deleted" timestamp,
  PRIMARY KEY ("id")
);

;
--
-- Table: permission
--
CREATE TABLE "permission" (
  "id" serial NOT NULL,
  "name" text NOT NULL,
  "description" text,
  PRIMARY KEY ("id")
);

;
--
-- Table: site
--
CREATE TABLE "site" (
  "id" serial NOT NULL,
  "name" text,
  "org_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "site_idx_org_id" on "site" ("org_id");

;
--
-- Table: site_group
--
CREATE TABLE "site_group" (
  "id" serial NOT NULL,
  "site_id" integer NOT NULL,
  "group_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "site_group_idx_group_id" on "site_group" ("group_id");
CREATE INDEX "site_group_idx_site_id" on "site_group" ("site_id");

;
--
-- Table: site_task
--
CREATE TABLE "site_task" (
  "id" serial NOT NULL,
  "task_id" integer,
  "site_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "site_task_idx_site_id" on "site_task" ("site_id");
CREATE INDEX "site_task_idx_task_id" on "site_task" ("task_id");

;
--
-- Table: task
--
CREATE TABLE "task" (
  "id" serial NOT NULL,
  "name" text,
  "description" text,
  "contractor_requirements" text,
  "evidence_required" text,
  "statutory" text,
  "period_unit" character varying(45) NOT NULL,
  "period_qty" integer NOT NULL,
  "global" smallint DEFAULT 1 NOT NULL,
  "site_check" smallint DEFAULT 0 NOT NULL,
  "tasktype_id" integer,
  "deleted" timestamp,
  PRIMARY KEY ("id")
);
CREATE INDEX "task_idx_tasktype_id" on "task" ("tasktype_id");

;
--
-- Table: tasktype
--
CREATE TABLE "tasktype" (
  "id" serial NOT NULL,
  "name" text,
  PRIMARY KEY ("id")
);

;
--
-- Table: ticket
--
CREATE TABLE "ticket" (
  "id" serial NOT NULL,
  "name" text,
  "description" text,
  "created_by" integer,
  "created_at" timestamp,
  "provisional" date,
  "planned" date,
  "completed" date,
  "cancelled" date,
  "contractor_id" integer,
  "task_id" integer,
  "site_id" integer,
  "cost_planned" numeric(10,2),
  "cost_actual" numeric(10,2),
  "local_only" smallint DEFAULT 0 NOT NULL,
  "report_received" smallint DEFAULT 0 NOT NULL,
  "contractor_invoice" text,
  "invoice_sent" smallint DEFAULT 0 NOT NULL,
  "actionee" character varying(16),
  PRIMARY KEY ("id")
);
CREATE INDEX "ticket_idx_contractor_id" on "ticket" ("contractor_id");
CREATE INDEX "ticket_idx_created_by" on "ticket" ("created_by");
CREATE INDEX "ticket_idx_site_id" on "ticket" ("site_id");
CREATE INDEX "ticket_idx_task_id" on "ticket" ("task_id");

;
--
-- Foreign Key Definitions
--

;
ALTER TABLE "attach" ADD CONSTRAINT "attach_fk_ticket_id" FOREIGN KEY ("ticket_id")
  REFERENCES "ticket" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "audit" ADD CONSTRAINT "audit_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_done" ADD CONSTRAINT "check_done_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_done" ADD CONSTRAINT "check_done_fk_site_task_id" FOREIGN KEY ("site_task_id")
  REFERENCES "site_task" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_item" ADD CONSTRAINT "check_item_fk_task_id" FOREIGN KEY ("task_id")
  REFERENCES "task" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_item_done" ADD CONSTRAINT "check_item_done_fk_check_done_id" FOREIGN KEY ("check_done_id")
  REFERENCES "check_done" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_item_done" ADD CONSTRAINT "check_item_done_fk_check_item_id" FOREIGN KEY ("check_item_id")
  REFERENCES "check_item" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_item_done" ADD CONSTRAINT "check_item_done_fk_status_custom" FOREIGN KEY ("status_custom")
  REFERENCES "check_item_option" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "check_item_option" ADD CONSTRAINT "check_item_option_fk_check_item_id" FOREIGN KEY ("check_item_id")
  REFERENCES "check_item" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "comment" ADD CONSTRAINT "comment_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "comment" ADD CONSTRAINT "comment_fk_ticket_id" FOREIGN KEY ("ticket_id")
  REFERENCES "ticket" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "event_org" ADD CONSTRAINT "event_org_fk_event_id" FOREIGN KEY ("event_id")
  REFERENCES "event" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "event_org" ADD CONSTRAINT "event_org_fk_org_id" FOREIGN KEY ("org_id")
  REFERENCES "org" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "invoice" ADD CONSTRAINT "invoice_fk_ticket_id" FOREIGN KEY ("ticket_id")
  REFERENCES "ticket" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "login_notice" ADD CONSTRAINT "login_notice_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "login_notice" ADD CONSTRAINT "login_notice_fk_notice_id" FOREIGN KEY ("notice_id")
  REFERENCES "notice" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "login_org" ADD CONSTRAINT "login_org_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "login_org" ADD CONSTRAINT "login_org_fk_org_id" FOREIGN KEY ("org_id")
  REFERENCES "org" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "login_permission" ADD CONSTRAINT "login_permission_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "login_permission" ADD CONSTRAINT "login_permission_fk_permission_id" FOREIGN KEY ("permission_id")
  REFERENCES "permission" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "site" ADD CONSTRAINT "site_fk_org_id" FOREIGN KEY ("org_id")
  REFERENCES "org" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "site_group" ADD CONSTRAINT "site_group_fk_group_id" FOREIGN KEY ("group_id")
  REFERENCES "group" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "site_group" ADD CONSTRAINT "site_group_fk_site_id" FOREIGN KEY ("site_id")
  REFERENCES "site" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "site_task" ADD CONSTRAINT "site_task_fk_site_id" FOREIGN KEY ("site_id")
  REFERENCES "site" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "site_task" ADD CONSTRAINT "site_task_fk_task_id" FOREIGN KEY ("task_id")
  REFERENCES "task" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "task" ADD CONSTRAINT "task_fk_tasktype_id" FOREIGN KEY ("tasktype_id")
  REFERENCES "tasktype" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "ticket" ADD CONSTRAINT "ticket_fk_contractor_id" FOREIGN KEY ("contractor_id")
  REFERENCES "contractor" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "ticket" ADD CONSTRAINT "ticket_fk_created_by" FOREIGN KEY ("created_by")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "ticket" ADD CONSTRAINT "ticket_fk_site_id" FOREIGN KEY ("site_id")
  REFERENCES "site" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "ticket" ADD CONSTRAINT "ticket_fk_task_id" FOREIGN KEY ("task_id")
  REFERENCES "task" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
