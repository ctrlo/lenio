-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/7/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/6/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE org DROP COLUMN case_number;

;
ALTER TABLE invoice DROP FOREIGN KEY invoice_fk_ticket_id;

;
DROP TABLE invoice;

;

COMMIT;

