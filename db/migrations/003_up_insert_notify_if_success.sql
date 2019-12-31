
BEGIN;

USE ftg;

ALTER TABLE Jobs
ADD COLUMN alarm_if_success INTEGER DEFAULT 0 -- Send Email to contacts in the Alarms table if the execution is successful
AFTER alarm_if_fail;

COMMIT;
