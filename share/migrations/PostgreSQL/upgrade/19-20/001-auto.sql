-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/19/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/20/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "group" (
  "id" serial NOT NULL,
  "name" text,
  PRIMARY KEY ("id")
);

;
CREATE TABLE "site_group" (
  "id" serial NOT NULL,
  "site_id" integer NOT NULL,
  "group_id" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "site_group_idx_group_id" on "site_group" ("group_id");
CREATE INDEX "site_group_idx_site_id" on "site_group" ("site_id");

;
ALTER TABLE "site_group" ADD CONSTRAINT "site_group_fk_group_id" FOREIGN KEY ("group_id")
  REFERENCES "group" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE "site_group" ADD CONSTRAINT "site_group_fk_site_id" FOREIGN KEY ("site_id")
  REFERENCES "site" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

