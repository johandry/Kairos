# From {source.user}
USER=$1
# From {source.passwd}
PASS=$2
# From {source.ip}
HOST=$3
# From {source.filename}
FILE=$4

filename="${FILE##*/}"
dir="${FILE%/*}/"

echo "Getting files from ${dir}"

ftp -ni ${HOST} << FTP_CMD
user ${USER} ${PASS}
cd ${dir}
ls
bye
FTP_CMD