# From {source.user}
USER=$1
# From {source.passwd}
PASS=$2
# From {source.ip}
HOST=$3
# From {source.filename}
FILE=$4

function help {
  cat <<EOH
Usage: 

${0##*/} user password host file-pattern

  Example: ${0##*/} user1 secr3t 10.0.0.1 /files/to/get/*
   
  or

${0##*/} --help
  To print this help.

EOH
exit 1
}

[[ -z "$1" || "$1" -eq "--help" || -z "$4"]] && help

FileList="/tmp/FTPMoveRen.list"

function pre_action {
  echo "Getting the list of files to transfer"
  ./FTPMoveRen_List.sh "$1" "$2" "$3" "$4" | awk '{print $9}' > ${FileList}
  echo "Edit the file ${FileList} to remove the files you do not want to move and rename."
  exit 0
}

[[ ! -f ${FileList} ]] && pre_action

filesCount=`wc -l ${FileList} | cut -d' ' -f1`

echo "Using the file ${FileList} to process ${filesCount} files. Press Cntrl+C if you want to edit the file first or Enter to continue."
read

dir=${FILE%/*}
i=1
totalTime=0

for f in `cat ${FileList}`
do 
  start=$( date +"%s" )
  sleep 1
  ./FTPMoveRen.sh "$USER" "$PASS" "$HOST" "${dir}/{f}" > "${0%.sh}.log"
  end=$( date +"%s" )
  difftime=$(( end - start ))
  (( totalTime += difftime ))
  eta=$(( (filesCount - i) * difftime ))
  etaMin=$(( eta / 60 ))
  etaSec=$(( eta % 60 ))
  (( i += 1 ))
  percentage=$( echo "scale=2; $i*100/$filesCount" | bc )
  donebar=$( echo "scale=0; 4 * ( $percentage / 10 )" | bc )
  notdonebar=$( echo "scale=0; 4 * 10 - $donebar" | bc )
  printf "\r %02d:%02d %3.1f%% [" $etaMin $etaSec $percentage 
  [[ ${donebar} > 0 ]] && printf '=%.0s' $(seq 1 $donebar)
  [[ ${notdonebar} > 0 ]] && printf '.%.0s' $( seq 1 $notdonebar)
  printf "]"
done
echo
totalMin=$(( totalTime / 60 ))
totalSec=$(( totalTime % 60 ))
printf " Total Time: %02d:%02d\n" $totalMin $totalSec

