-- Convert schema '/home/abeverley/git/lenio/share/migrations/_source/deploy/4/001-auto.yml' to '/home/abeverley/git/lenio/share/migrations/_source/deploy/5/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE check_item DROP CONSTRAINT check_item_fk_task_id;

;
ALTER TABLE check_item ADD CONSTRAINT check_item_fk_task_id FOREIGN KEY (task_id)
  REFERENCES task (id) ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;
ALTER TABLE check_item_done DROP CONSTRAINT check_item_done_fk_check_item_id;

;
ALTER TABLE check_item_done ADD CONSTRAINT check_item_done_fk_check_item_id FOREIGN KEY (check_item_id)
  REFERENCES check_item (id) ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE;

;

COMMIT;

