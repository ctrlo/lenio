-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/2/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/1/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ticket DROP COLUMN report_received,
                   DROP COLUMN invoice_sent;

;

COMMIT;

