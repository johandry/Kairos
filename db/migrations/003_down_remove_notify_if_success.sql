
BEGIN;

USE ftg;

ALTER TABLE Jobs
DROP COLUMN alarm_if_success;

COMMIT;
