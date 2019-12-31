#!/bin/bash

# Update this line if doxTG is installed in other directory
doxTGCronLog="/opt/FTG/doxTG/logs/cron.log";

# Threshold for Jobs Failed
jobsFailedWarning=3
jobsFailedCritical=6

tmpCountExecFile="/tmp/doxTGJobCount";
tmpCountFailFile="/tmp/doxTGJobCountFail";
tmpLastExecFile="/tmp/doxTGLastJobExec";

totalExecDay=`grep "STARTING - Starting Job " ${doxTGCronLog} | wc -l 2>/dev/null`;              [[ -z ${totalExecDay} ]] && totalExecDay=0;

jobsExecuted=0;
lastJobExec01=`cat ${tmpLastExecFile} | cut -d " " -f1 2>/dev/null`; [[ -z ${lastJobExec01} ]] && lastJobExec01=0;
lastJobExec02=`cat ${tmpLastExecFile} | cut -d " " -f2 2>/dev/null`; [[ -z ${lastJobExec02} ]] && lastJobExec02=0;

lastTotal01=`cat ${tmpCountExecFile} | cut -d " " -f1 2>/dev/null`;    [[ -z ${lastTotal01} ]] && lastTotal01=0;
lastTotal02=`cat ${tmpCountExecFile} | cut -d " " -f2 2>/dev/null`;    [[ -z ${lastTotal02} ]] && lastTotal02=0;

if [[ ${totalExecDay} -ge ${lastTotal01} ]]
  then
  let "jobsExecuted = ${totalExecDay} - ${lastTotal01}";
else
  jobsExecuted=${totalExecDay};
fi

echo "${jobsExecuted} ${lastJobExec01}" > ${tmpLastExecFile};
echo "${totalExecDay} ${lastTotal01}"   > ${tmpCountExecFile};

totalFailDay=`grep "FAILURE - Ending Job " ${doxTGCronLog} | wc -l 2>/dev/null`; [[ -z ${totalFailDay} ]] && totalFailDay=0;

jobsFailed=0;
lastTotalFail=`cat ${tmpCountFailFile} | cut -d " " -f2 2>/dev/null`;  [[ -z ${lastTotalFail} ]] && lastTotalFail=0;

if [[ ${totalFailDay} -ge ${lastTotalFail} ]]
  then
  let "jobsFailed = ${totalFailDay} - ${lastTotalFail}";
else
  jobsExecuted=${totalFailDay};
fi

echo "${totalFailDay}" > ${tmpCountFailFile};

# If jobsExecuted == 0 is OK because in the last monitring minutes could not ran any Job
status="OK";

# If jobsExecuted == 0 and in the previous last monitoring minutes no Job was executed then we could have a possible problem
[[ ${lastJobExec01} -eq "0" ]] && [[ "${jobsExecuted}" -eq "0" ]] && status="WARNING";

# If in the last 3 monitoring minutes no Job was executed then we have a problem
[[ ${lastJobExec01} -eq "0" ]] && [[ ${lastJobExec02} -eq "0" ]] && [[ "${jobsExecuted}" -eq "0" ]] && status="CRITICAL";

# If Status is not CRITICAL and Jobs Failed is great than 3, it is WARNING
[[ ${status} -ne "CRITICAL" ]] && [[ ${jobsFailed} -gt "${jobsFailedWarning}" ]] && status="WARNING";

# If Jobs Failed is great than 6, status is CRITICAL
[[ ${jobsFailed} -gt "${jobsFailedCritical}" ]] && status="CRITICAL";

# IMPORTANT: Define the monitoring minutes according to your schedules and daily activity

# echo "DOXTG ${status} - Jobs Executed: ${jobsExecuted}; | Jobs=${totalExecDay};${lastTotal01};${lastTotal02}";
echo "DOXTG ${status} - Jobs Executed: ${jobsExecuted}, Jobs Failed: ${jobsFailed} | 'Jobs Executed'=${jobsExecuted}, 'Jobs Failed'=${jobsFailed};${jobsFailedWarning};${jobsFailedCritical};0"

[[ ${status} == "OK" ]]       && exit 0;
[[ ${status} == "WARNING" ]]  && exit 1;
[[ ${status} == "CRITICAL" ]] && exit 2;
exit 3;
