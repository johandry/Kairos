
BEGIN;

USE ftg;

DROP TABLE Users;
DROP TABLE Roles;
DROP TABLE JobInstances;
DROP TABLE Alarms;
DROP TABLE JobsCommands;
DROP TABLE Conditions;
DROP TABLE Jobs;
DROP TABLE JobGroups;
DROP TABLE Actions;
DROP TABLE Commands;
DROP TABLE CommandTypes;
DROP TABLE Triggers;
DROP TABLE Statuses;
DROP TABLE Filewatchers;
DROP TABLE Schedules;
DROP TABLE Filetransfers;
DROP TABLE Protocols;
DROP TABLE Containers;
DROP TABLE Files;
DROP TABLE Machines;
DROP TABLE Datacenters;
DROP TABLE Credentials;
DROP TABLE Contacts;
DROP TABLE Teams;

COMMIT;
