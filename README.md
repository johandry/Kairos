# Kairos

Kairos is a job scheduler and event driven file transfer - similar to AutoSys or Jenkins - to transfer remote files and execute remote commands

## Start/Stop Kairos

This is for development only. For a production environment Kairos is deployed with apache and you do not need to start or stop it.

Start:
cd $FTG_HOME && ./bin/kairos.sh --start

Stop:
cd $FTG_HOME && ./bin/kairos.sh --stop

Status:
cd $FTG_HOME && ./bin/kairos.sh --status

The $FTG_HOME variable is where Kairos is installed.
