-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/3/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/4/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE attach DROP FOREIGN KEY attach_fk_ticket_id;

;
ALTER TABLE attach ADD CONSTRAINT attach_fk_ticket_id FOREIGN KEY (ticket_id) REFERENCES ticket (id) ON DELETE CASCADE ON UPDATE NO ACTION;

;
ALTER TABLE comment DROP FOREIGN KEY comment_fk_ticket_id;

;
ALTER TABLE comment ADD CONSTRAINT comment_fk_ticket_id FOREIGN KEY (ticket_id) REFERENCES ticket (id) ON DELETE CASCADE ON UPDATE NO ACTION;

;

COMMIT;

