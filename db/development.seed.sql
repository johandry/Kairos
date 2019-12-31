-- Credentials

INSERT INTO Credentials (id, username, password, contact_id, description) VALUES (1, 'dummyuser', 'testing',  1, 'Dummy user for testing');
INSERT INTO Credentials (id, username, password, contact_id, description) VALUES (2, 'ja6351',    'amador76', 1, 'Johandry''s account for testing');

-- Files

INSERT INTO Files (id, name, type, description) VALUES (1, '/tmp/ftg.tst', 'F', 'FTG testing file');
INSERT INTO Files (id, name, type, description) VALUES (2, 'test.txt',     'F', 'Testing file.');
INSERT INTO Files (id, name, type, description) VALUES (3, 'test_OK.txt',  'F', 'Final testing file');
INSERT INTO Files (id, name, type, description) VALUES (4, '{FTG_SCRIPTS}/flag.sh',    'S', 'General script to flag a file adding ''.FIN'' to the end of the file.');
INSERT INTO Files (id, name, type, description) VALUES (5, '{FTG_SCRIPTS}/delete.sh',  'S', 'General script to delete a file.');
INSERT INTO Files (id, name, type, description) VALUES (6, '{FTG_SCRIPTS}/history.sh', 'S', 'General script to copy the file to the history directory ''HIST''.');
INSERT INTO Files (id, name, type, description) VALUES (7, '{FTG_SCRIPTS}/test.sh',    'S', 'Test Script.');
INSERT INTO Files (id, name, type, description) VALUES (8, '{FTG_SCRIPTS}/validate.sh','S', 'Validate Script to check file before/after transfer it.');
INSERT INTO Files (id, name, type, description) VALUES (9, '{FTG_SCRIPTS}/notify.sh',  'S', 'Notify a user.');

-- Containers

INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (1, 'ja6351@fltva073:{FTG_SCRIPTS}/flag.sh',    4, 1, 1, 'FTG Script to Flag files.');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (2, 'ja6351@fltva073:{FTG_SCRIPTS}/delete.sh',  5, 1, 1, 'FTG Script to Delete files.');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (3, 'ja6351@fltva073:{FTG_SCRIPTS}/history.sh', 6, 1, 1, 'FTG Script to History files.');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (4, 'ja6351@fltva073:test.txt',                 2, 1, 2, 'Testing file at fltva073');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (5, 'ja6351@fltva052:test_OK.txt',              3, 6, 2, 'Testing file copied to fltva052');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (6, 'ja6351@fltva073:{FTG_SCRIPTS}/test.sh',    7, 1, 1, 'FTG Script to Test.');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (7, 'ja6351@fltva073:{FTG_SCRIPTS}/validate.sh',8, 1, 1, 'FTG Script to Validate the file before/after transfer it.');
INSERT INTO Containers (id, name, file_id, machine_id, credential_id, description) VALUES (8, 'ja6351@fltva073:{FTG_SCRIPTS}/notify.sh',  9, 1, 1, 'FTG Script to Notify a user.');

-- Filetransfers

INSERT INTO Filetransfers (id, name, source_id, target_id, protocol_id, description) VALUES (1, 'ja6351@fltva073:test.txt>SCP>ja6351@fltva052:test_OK.txt',             4, 5, 1, 'Testing SCP');
INSERT INTO Filetransfers (id, name, source_id, target_id, protocol_id, description) VALUES (2, 'ja6351@fltva073:test.txt>SFTP>ja6351@fltva052:test_OK.txt',            5, 4, 2, 'Testing SFTP');

-- Schedules

INSERT INTO Schedules (id, name, minutes, hours, month_days, months, week_days, description) VALUES (1, '*/5', '*/5', NULL, NULL, NULL, NULL, 'Every 5 minutes');
INSERT INTO Schedules (id, name, minutes, hours, month_days, months, week_days, description) VALUES (2, '10:00, 16:00', NULL, '10,16', NULL, NULL, NULL, 'Every day at 10:00 AM and 4:00 PM');

-- Filewatchers

INSERT INTO Filewatchers (id, name, container_id, schedule_id, description) VALUES (1, 'fltva073:/tmp/ftg.tst#*/5', 4, 1, 'Check the file /tmp/ftg.tst every 5 minutes');

-- Conditions

INSERT INTO Conditions (id, name, status_id, job_id, schedule_id, description) VALUES (1, 'SU(Schedule Test)#*/5', 5, 1, 1, 'Check every 5 minutes if job ''FTG Test'' ran SUccessfuly');

-- Alarms

INSERT INTO Alarms (id, job_id, contact_id) VALUES (1, 1, 1);
INSERT INTO Alarms (id, job_id, contact_id) VALUES (2, 1, 2);
INSERT INTO Alarms (id, job_id, contact_id) VALUES (3, 2, 1);
INSERT INTO Alarms (id, job_id, contact_id) VALUES (4, 3, 2);

-- Commands

INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (1, 'Flag',         1, '{source.filename}', 1, 2, 'Add a flag ''.FIN'' to the end of the source file name.');
INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (2, 'Delete',       2, '{source.filename}', 1, 2, 'Delete the source file after transfer it.');
INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (3, 'History',      3, '{source.filename}', 1, 2, 'Copy the source file to the history directory.');
INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (4, 'Test Command', 6, 'Test',              0, 3, 'Testing Command.');
INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (5, 'Pre Validate', 7, '{source.filename}', 1, 1, 'Validate file before transfer it.');
INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (6, 'Post Validate',7, '{target.filename}', 1, 2, 'Validate file after transfer it.');
INSERT INTO Commands (id, name, container_id, parameters, system, type, description) VALUES (7, 'Notify',       8, 'ja6351@yp.com',     0, 5, 'Notify at any time.');

-- JobsCommands

INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 1, 1, 1, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 2, 2, 1, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 3, 2, 2, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 4, 3, 1, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 5, 3, 3, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 6, 4, 2, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 7, 5, 3, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 8, 6, 5, 1);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES ( 9, 6, 7, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES (10, 6, 2, 2);
INSERT INTO JobsCommands (id, job_id, command_id, type) VALUES (11, 6, 3, 2);

-- Jobs
/*                                                                                                                                   id, name,                                a, at, t, tt,c, a, alr, description */
INSERT INTO Jobs (id, name, action_id, action_type, trigger_id, trigger_type, contact_id, active, alarm_if_fail, description) VALUES (1, 'Schedule Test',                      1, 1, 2, 2, 1, 1, 1, 'FTG Testing file every day at 10:00 AM and 4:00 PM. Will send an alarm if fails.');
INSERT INTO Jobs (id, name, action_id, action_type, trigger_id, trigger_type, contact_id, active, alarm_if_fail, description) VALUES (2, 'FW Test',                            1, 1, 1, 1, 1, 1, 1, 'FTG Testing file when exists and is closed. Will send an alarm if fails.');
INSERT INTO Jobs (id, name, action_id, action_type, trigger_id, trigger_type, contact_id, active, alarm_if_fail, description) VALUES (3, 'Conditioned Job',                    1, 1, 1, 3, 1, 1, 1, 'FTG Testing file when the job ''FTG Test'' ran SUccessfuly. Will send an alarm if fails.');
INSERT INTO Jobs (id, name, action_id, action_type, trigger_id, trigger_type, contact_id, active, alarm_if_fail, description) VALUES (4, 'Test SCP from fltva073 to fltva052', 2, 1, 1, 2, 1, 1, 1, 'Testing SCP');
INSERT INTO Jobs (id, name, action_id, action_type, trigger_id, trigger_type, contact_id, active, alarm_if_fail, description) VALUES (5, 'Test SFTP from fltva073 to fltva052',2, 1, 1, 2, 1, 1, 1, 'Testing SFTP');
INSERT INTO Jobs (id, name, action_id, action_type, trigger_id, trigger_type, contact_id, active, alarm_if_fail, description) VALUES (6, 'Test Command',                       4, 2, 1, 2, 1, 1, 1, 'Testing Command');
