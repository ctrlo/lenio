-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/1/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket ADD COLUMN report_received smallint NOT NULL DEFAULT 0,
                   ADD COLUMN invoice_sent smallint NOT NULL DEFAULT 0;

;

COMMIT;

