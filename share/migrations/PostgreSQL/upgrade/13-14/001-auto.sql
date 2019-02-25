-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/13/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/14/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "check_item_option" (
  "id" serial NOT NULL,
  "name" text,
  "check_item_id" integer,
  "is_deleted" smallint DEFAULT 0 NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "check_item_option_idx_check_item_id" on "check_item_option" ("check_item_id");

;
ALTER TABLE "check_item_option" ADD CONSTRAINT "check_item_option_fk_check_item_id" FOREIGN KEY ("check_item_id")
  REFERENCES "check_item" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE check_item ADD COLUMN has_custom_options smallint DEFAULT 0 NOT NULL;

;
ALTER TABLE check_item_done ADD COLUMN status_custom integer;

;
CREATE INDEX check_item_done_idx_status_custom on check_item_done (status_custom);

;
ALTER TABLE check_item_done ADD CONSTRAINT check_item_done_fk_status_custom FOREIGN KEY (status_custom)
  REFERENCES check_item_option (id) ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

