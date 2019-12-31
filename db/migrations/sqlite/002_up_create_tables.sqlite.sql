PRAGMA foreign_keys=ON;
BEGIN TRANSACTION;

-- USE ftg;

/*
TABLE: Teams
DESC:  It is a real team such as UNIX Admins, DBAs or Human Resources.
*/

CREATE TABLE IF NOT EXISTS Teams (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  email         TEXT,
  description   TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Teams_created_on AFTER INSERT 
ON Teams
BEGIN
  UPDATE Teams SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

-- First Team need to be the application team

INSERT INTO Teams (name, email, description) VALUES ('doXTG', 'unixdo@yp.com', 'Group of doXTG Administrators');

/*
TABLE: Contacts
DESC:  It is a real user.
*/

CREATE TABLE IF NOT EXISTS Contacts (
  id            INTEGER PRIMARY KEY NOT NULL,
  corpid        TEXT    NOT NULL,   
  firstname     TEXT    NOT NULL,
  lastname      TEXT,
  email         TEXT,
  team_id       INTEGER,
  created_on    DATETIME,

  FOREIGN KEY(team_id) REFERENCES Teams(id)
);

CREATE TRIGGER insert_Contacts_created_on AFTER INSERT 
ON Contacts
BEGIN
  UPDATE Contacts SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

-- First Contact need to be the application admin

INSERT INTO Contacts (corpid, firstname, lastname, email, team_id) VALUES ('doxtg',  'doXTG',    'Administrator', 'doxtg@yp.com',  1);
INSERT INTO Contacts (corpid, firstname, lastname, email, team_id) VALUES ('ja6351', 'Johandry', 'Amador',        'ja6351@yp.com', 1);

/*
TABLE: Credentials
DESC:  It is a unix user that may be associated to a real user.
*/

CREATE TABLE IF NOT EXISTS Credentials (
  id            INTEGER PRIMARY KEY NOT NULL,
  username      TEXT    NOT NULL,
  password      TEXT    NOT NULL,
  contact_id    INTEGER,
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(contact_id) REFERENCES Contacts(id)
);

CREATE TRIGGER insert_Credentials_created_on AFTER INSERT 
ON Credentials
BEGIN
  UPDATE Credentials SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Datacenters
DESC:  It is a datacenter to store Machines. They are not inserted using the application, they will be added manually to the DB
*/

CREATE TABLE IF NOT EXISTS Datacenters (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  address       TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Datacenters_created_on AFTER INSERT 
ON Datacenters
BEGIN
  UPDATE Datacenters SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Datacenters (name, address) VALUES ('Fairfield', 'Fairfield, CA, US');

/*
TABLE: Machines
DESC:  Servers in a DC
*/

CREATE TABLE IF NOT EXISTS Machines (
  id            INTEGER PRIMARY KEY NOT NULL,
  hostname      TEXT    NOT NULL,
  domainname    TEXT,
  ip            TEXT,
  dc_id         INTEGER,
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(dc_id) REFERENCES Datacenters(id)
);

CREATE TRIGGER insert_Machines_created_on AFTER INSERT 
ON Machines
BEGIN
  UPDATE Machines SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Machines (hostname, domainname, ip, dc_id, description) VALUES ('fltva073', 'ffdc.sbc.com', '135.161.22.132', 1, 'doXTG QA Environment');
INSERT INTO Machines (hostname, domainname, ip, dc_id, description) VALUES ('fltva048', 'ffdc.sbc.com', '135.161.22.67',  1, 'doXTG Testing Machine');
INSERT INTO Machines (hostname, domainname, ip, dc_id, description) VALUES ('fltva049', 'ffdc.sbc.com', '135.161.22.69',  1, 'doXTG Testing Machine');
INSERT INTO Machines (hostname, domainname, ip, dc_id, description) VALUES ('fltva050', 'ffdc.sbc.com', '135.161.22.95',  1, 'doXTG Testing Machine');
INSERT INTO Machines (hostname, domainname, ip, dc_id, description) VALUES ('fltva051', 'ffdc.sbc.com', '135.161.22.96',  1, 'doXTG Testing Machine');
INSERT INTO Machines (hostname, domainname, ip, dc_id, description) VALUES ('fltva052', 'ffdc.sbc.com', '135.161.22.100', 1, 'Puppet and doxTG Testing Machine');

/*
TABLE: Files
DESC:  File name, regular expresion or glob for a file. It should include the path and name
*/

CREATE TABLE IF NOT EXISTS Files (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  type          TEXT    NOT NULL, -- DEFAULT 'F',  -- 'F' = File, 'S' = Script
  description   TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Files_created_on AFTER INSERT 
ON Files
BEGIN
  UPDATE Files SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Containers
DESC:  An contatiner is a file in a machine accesible with a credentials or a new file name to move to a machine with credentials.
*/

CREATE TABLE IF NOT EXISTS Containers (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT        NOT NULL, -- name=user@machine:filename
  file_id       INTEGER     NOT NULL,
  machine_id    INTEGER     NOT NULL,
  credential_id INTEGER     NOT NULL,
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(file_id)        REFERENCES Files(id),
  FOREIGN KEY(machine_id)     REFERENCES Machines(id),
  FOREIGN KEY(credential_id)  REFERENCES Credentials(id)
);

CREATE TRIGGER insert_Containers_created_on AFTER INSERT 
ON Containers
BEGIN
  UPDATE Containers SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Protocols
DESC:  Protocols used to transfer containers from one machine to other. As they are just a few, they will be added manually to the DB, not using the App.
*/

CREATE TABLE IF NOT EXISTS Protocols (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  classname     TEXT    NOT NULL,
  description   TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Protocols_created_on AFTER INSERT 
ON Protocols
BEGIN
  UPDATE Protocols SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Protocols (name, classname, description) VALUES ('SCP',  'scp', 'Secure Copy');
INSERT INTO Protocols (name, classname, description) VALUES ('SFTP', 'sftp','Secure Copy allowing passwords with Expect');

/*
TABLE: Filetransfers
DESC:  Transfer an container from one machine to other machine.
*/  

CREATE TABLE IF NOT EXISTS Filetransfers (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT        NOT NULL, -- user@machine:filename>protocol>user@machine:filename
  source_id     INTEGER     NOT NULL,
  target_id     INTEGER     NOT NULL,
  protocol_id   INTEGER     NOT NULL,
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(source_id)    REFERENCES Containers(id),
  FOREIGN KEY(target_id)    REFERENCES Containers(id),
  FOREIGN KEY(protocol_id)  REFERENCES Protocols(id)
);

CREATE TRIGGER insert_Filetransfers_created_on AFTER INSERT 
ON Filetransfers
BEGIN
  UPDATE Filetransfers SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Schedules
DESC:  Schedule to execute a job.
*/  

CREATE TABLE IF NOT EXISTS Schedules (
  id            INTEGER  PRIMARY KEY NOT NULL,
  name          TEXT  NOT NULL,
  minutes       TEXT,
  hours         TEXT,
  month_days    TEXT,
  months        TEXT,
  week_days     TEXT,
  description   TEXT  NOT NULL,
  created_on    DATETIME
);

CREATE TRIGGER insert_Schedules_created_on AFTER INSERT 
ON Schedules
BEGIN
  UPDATE Schedules SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Filewatchers
DESC:  Check in a period of time for a file. When the file exists a job will be triggered.
*/

CREATE TABLE IF NOT EXISTS Filewatchers (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  container_id  INTEGER NOT NULL,
  schedule_id   INTEGER NOT NULL,
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(container_id) REFERENCES Containers(id),
  FOREIGN KEY(schedule_id)  REFERENCES Schedules(id)
);

CREATE TRIGGER insert_Filewatchers_created_on AFTER INSERT 
ON Filewatchers
BEGIN
  UPDATE Filewatchers SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Conditions
iDESC:  Check, base on the schedule, if the job has the status defined. If so, the condition is true and will trigger a job.
*/

CREATE TABLE IF NOT EXISTS Conditions (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  status_id     INTEGER NOT NULL,
  job_id        INTEGER NOT NULL,
  schedule_id   INTEGER NOT NULL,
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(status_id)   REFERENCES Statuses(id),
  FOREIGN KEY(job_id)      REFERENCES Jobs(id),
  FOREIGN KEY(schedule_id) REFERENCES Schedules(id)
);

CREATE TRIGGER insert_Conditions_created_on AFTER INSERT 
ON Conditions
BEGIN
  UPDATE Conditions SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Triggers
DESC:  Have a collection of Triggers that could be a Filewatcher, Condition or Schedule to execute the Job. It reference the table to consult with the trigger_id
*/

CREATE TABLE IF NOT EXISTS Triggers (
  id          INTEGER PRIMARY KEY NOT NULL,
  name        TEXT    NOT NULL,
  table_name  TEXT    NOT NULL,
  description TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Triggers_created_on AFTER INSERT 
ON Triggers
BEGIN
  UPDATE Triggers SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Triggers (name, table_name, description) VALUES ('Filewatcher', 'Filewatchers', 'Check for a file to exists and be close based on a schedule');
INSERT INTO Triggers (name, table_name, description) VALUES ('Schedule', 'Schedules', 'Check for a file to exists and be close based on a schedule');
INSERT INTO Triggers (name, table_name, description) VALUES ('Condition', 'Conditions', 'Check for a file to exists and be close based on a schedule');

/*
TABLE: Alarms
DESC:  Actions to execute after the execution of the job if it was sucessful
*/

CREATE TABLE IF NOT EXISTS Alarms (
  id            INTEGER PRIMARY KEY NOT NULL,
  job_id        INTEGER NOT NULL,
  contact_id    INTEGER NOT NULL,
  created_on    DATETIME,

  FOREIGN KEY(job_id)       REFERENCES Jobs(id),
  FOREIGN KEY(contact_id)   REFERENCES Contacts(id)
);

CREATE TRIGGER insert_Alarms_created_on AFTER INSERT 
ON Alarms
BEGIN
  UPDATE Alarms SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: CommandType
DESC:  When the command could be executed: pre_action, post_action, any time
*/

CREATE TABLE IF NOT EXISTS CommandTypes (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  created_on    DATETIME
);

CREATE TRIGGER insert_CommandTypes_created_on AFTER INSERT 
ON CommandTypes
BEGIN
  UPDATE CommandTypes SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO CommandTypes (name) VALUES ('Pre Action');
INSERT INTO CommandTypes (name) VALUES ('Post Action');
INSERT INTO CommandTypes (name) VALUES ('In Action');
INSERT INTO CommandTypes (name) VALUES ('Pre/Post Action');
INSERT INTO CommandTypes (name) VALUES ('Any Action');

/*
TABLE: Commands
DESC:  Commands or scripts to execute
*/

CREATE TABLE IF NOT EXISTS Commands (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  container_id  INTEGER NOT NULL,
  parameters    TEXT,
  system        INTEGER DEFAULT 0, -- Standar commands are predefined. Are check box for a Job. Example: flag, delete or history
  type          INTEGER DEFAULT 3, -- When the command could be executed: pre_action, post_action, any time
  description   TEXT,
  created_on    DATETIME,

  FOREIGN KEY(container_id) REFERENCES Containers(id),
  FOREIGN KEY(type)         REFERENCES CommandTypes(id)
);

CREATE TRIGGER insert_Commands_created_on AFTER INSERT 
ON Commands
BEGIN
  UPDATE Commands SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: JobsCommands
DESC:  Relationship many to many for Jobs and Commands. A Job may have more than one command for pre or post commands. (only one as action)
*/

CREATE TABLE IF NOT EXISTS JobsCommands (
  id            INTEGER PRIMARY KEY NOT NULL,
  job_id        INTEGER NOT NULL,
  command_id    INTEGER NOT NULL,
  type          INTEGER DEFAULT 2, -- pre_action, post_action, in action
  created_on    DATETIME,

  FOREIGN KEY(job_id)       REFERENCES Jobs(id),
  FOREIGN KEY(command_id)   REFERENCES Commands(id),
  FOREIGN KEY(type)         REFERENCES CommandTypes(id)
);

CREATE TRIGGER insert_JobsCommands_created_on AFTER INSERT 
ON JobsCommands
BEGIN
  UPDATE JobsCommands SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Actions
DESC:  Actions type. Each Job can execute an action type such as FileTransfer or Command.
*/

CREATE TABLE IF NOT EXISTS Actions (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  table_name    TEXT    NOT NULL,
  description   TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Actions_created_on AFTER INSERT 
ON Actions
BEGIN
  UPDATE Actions SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Actions (name, table_name, description) VALUES ('Filetransfer', 'Filetransfers', 'Transfer a file from Source Server to Target Server.');
INSERT INTO Actions (name, table_name, description) VALUES ('Command',      'Commands',      'Execute a Command in a server.');

/*
TABLE: JobGroups
DESC:  To group the Jobs in sets.
*/

CREATE TABLE IF NOT EXISTS JobGroups (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  description   TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_JobGroups_created_on AFTER INSERT 
ON JobGroups
BEGIN
  UPDATE JobGroups SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Jobs
DESC:  Jobs to be executed on specific schedule to transfer files.
*/

CREATE TABLE IF NOT EXISTS Jobs (
  id               INTEGER PRIMARY KEY NOT NULL,
  name             TEXT    NOT NULL,
  group_id         INTEGER,
  action_id        INTEGER NOT NULL,
  action_type      INTEGER NOT NULL DEFAULT 1, -- File Transfer
  trigger_id       INTEGER NOT NULL,
  trigger_type     INTEGER NOT NULL,
  contact_id       INTEGER,          -- Job Owner/Requestor
  active           INTEGER DEFAULT 1,
  description      TEXT,  
  alarm_if_fail    INTEGER DEFAULT 0, -- Send Email to contacts in the Alarms table if the execution fail
  alarm_if_success INTEGER DEFAULT 0, -- Send Email to contacts in the Alarms table if the execution is successful
  created_on       DATETIME,

  FOREIGN KEY(group_id)     REFERENCES JobGroups(id),
  FOREIGN KEY(action_type)  REFERENCES Actions(id),
  FOREIGN KEY(trigger_type) REFERENCES Triggers(id),
  FOREIGN KEY(contact_id)   REFERENCES Contacts(id)
);

CREATE TRIGGER insert_Jobs_created_on AFTER INSERT 
ON Jobs
BEGIN
  UPDATE Jobs SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Statuses
DESC:  Status for every Job instance. They are like constants, so will be modified manually in the DB not thru the App
*/

CREATE TABLE IF NOT EXISTS Statuses (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  shortname     TEXT    NOT NULL, -- shortname: Two letters abbreviation for the status name.
  description   TEXT,
  created_on    DATETIME
);

CREATE TRIGGER insert_Statuses_created_on AFTER INSERT 
ON Statuses
BEGIN
  UPDATE Statuses SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Statuses (name, shortname, description) VALUES ('INACTIVE',   'IN', 'The job has not yet been processed. Either the job has never been run, or its status was intentionally altered to “turn off” its previous completion status');
INSERT INTO Statuses (name, shortname, description) VALUES ('ACTIVATED',  'AC', 'The top-level box that this job is in is now in the RUNNING state, but the job itself has not started yet.');
INSERT INTO Statuses (name, shortname, description) VALUES ('STARTING',   'ST', 'The event processor has initiated the start job procedure with the Remote Agent.');
INSERT INTO Statuses (name, shortname, description) VALUES ('RUNNING',    'RU', 'The job is running. The value means that the process is actually running on the remote machine.');
INSERT INTO Statuses (name, shortname, description) VALUES ('SUCCESS',    'SU', 'The job exited with an exit code equal to or less than the ''maximum exit code for success.'' By default, only the exit code ''0'' is interpreted as ''success.''');
INSERT INTO Statuses (name, shortname, description) VALUES ('FAILURE',    'FA', 'The job exited with an exit code greater than the ''maximum exit code for success.'' By default, any number greater than zero is interpreted as ''failure''. FTG issues an alarm if a job fails');
INSERT INTO Statuses (name, shortname, description) VALUES ('TERMINATED', 'TE', 'The job terminated while in the RUNNING state. A job can be terminated if a user sends a KILLJOB event or if it was defined to terminate if the box it is in failed. If the job itself fails, it has a FAILURE status, not a TERMINATED status. A job may also be terminated if it has exceeded the maximum run time (term_run_time attribute, if one was specified for the job), or if it was killed from the command line through a UNIX kill command. FTG issues an alarm if a job is terminated.');
INSERT INTO Statuses (name, shortname, description) VALUES ('RESTART',    'RE', 'The job was unable to start due to hardware or application problems, and has been scheduled to restart.');
INSERT INTO Statuses (name, shortname, description) VALUES ('QUE_WAIT',   'QW', 'The job can logically run (that is, all the starting conditions have been met), but there are not enough machine resources available.');
INSERT INTO Statuses (name, shortname, description) VALUES ('ON_HOLD',    'OH', 'This job is on hold and will not be run until it receives the JOB_OFF_HOLD event.');
INSERT INTO Statuses (name, shortname, description) VALUES ('ON_ICE',     'OI', 'This job is removed from all conditions and logic, but is still defined to FTG. Operationally, this condition is like deactivating the job. It will remain on ice until it receives the JOB_OFF_ICE event.');

/*
TABLE: JobInstances
DESC:  Instance or execution of every job.
*/

CREATE TABLE IF NOT EXISTS JobInstances (
  id            INTEGER  PRIMARY KEY NOT NULL,
  job_id        INTEGER  NOT NULL,
  start_on      DATETIME NOT NULL,
  end_on        DATETIME,
  status_id     INTEGER  NOT NULL,
  exit_code     INTEGER,
  results       TEXT,
  created_on    DATETIME,

  FOREIGN KEY(job_id)    REFERENCES Jobs(id),
  FOREIGN KEY(status_id) REFERENCES Statuses(id)
);

CREATE TRIGGER insert_JobInstances_created_on AFTER INSERT 
ON JobInstances
BEGIN
  UPDATE JobInstances SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

/*
TABLE: Roles
DESC:  Roles for users that will access the application.
*/

CREATE TABLE IF NOT EXISTS Roles (
  id            INTEGER PRIMARY KEY NOT NULL,
  name          TEXT    NOT NULL,
  created_on    DATETIME
);

CREATE TRIGGER insert_Roles_created_on AFTER INSERT 
ON Roles
BEGIN
  UPDATE Roles SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Roles (name) VALUES ('Admin');
INSERT INTO Roles (name) VALUES ('Guest');
INSERT INTO Roles (name) VALUES ('User');

/*
TABLE: Users
DESC:  Users to access the application.
*/

CREATE TABLE IF NOT EXISTS Users (
  id            INTEGER PRIMARY KEY NOT NULL,
  username      TEXT    NOT NULL,
  password      TEXT    NOT NULL,
  contact_id    INTEGER,
  role_id       INTEGER,
  created_on    DATETIME,

  FOREIGN KEY(contact_id) REFERENCES Contacts(id),
  FOREIGN KEY(role_id)    REFERENCES Roles(id)
);

CREATE TRIGGER insert_Users_created_on AFTER INSERT 
ON Users
BEGIN
  UPDATE Users SET created_on = DATETIME('NOW') WHERE rowid = new.rowid;
END;

INSERT INTO Users (username, password, contact_id, role_id) VALUES ('admin', '{SSHA}XqvndMUzPkr2HO1OGZPiznigY0jnNPFS',1,1);;
INSERT INTO Users (username, password, contact_id, role_id) VALUES ('ja6351','{SSHA}FIZldBbTcTR14rT67hyZ/rjsNAOAPC6Y',2,1);

COMMIT;
