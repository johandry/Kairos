
BEGIN;

USE ftg;

DELETE FROM protocols 
  WHERE name='SFTP/FTP (ASCII)';

UPDATE protocols
  SET name='SFTP/FTP', 
    classname='sftp',
    description='Secure Copy or FTP'
  WHERE id = 2;

COMMIT;