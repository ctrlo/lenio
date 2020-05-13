-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/16/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/17/001-auto.yml':;

;
BEGIN;

;
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
ALTER TABLE "audit" ADD CONSTRAINT "audit_fk_login_id" FOREIGN KEY ("login_id")
  REFERENCES "login" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

