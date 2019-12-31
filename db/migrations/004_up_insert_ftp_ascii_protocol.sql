
BEGIN;

USE ftg;

UPDATE Protocols
  SET name='SFTP/FTP (BIN)', 
    classname='sftp_bin',
    description='Secure Copy or FTP using BINARY'
  WHERE id = 2;

INSERT INTO Protocols 
  SET name='SFTP/FTP (ASCII)', 
    classname='sftp_ascii', 
    description='Secure Copy or FTP using ASCII';

COMMIT;