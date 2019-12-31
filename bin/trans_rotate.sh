#!/bin/bash

var_dir=/opt/FTG/doxTG/var_dir
today=`date --date yesterday +%Y%m%d`

mkdir -p ${var_dir}/${today}
mv ${var_dir}/*_IN_* ${var_dir}/${today}
# After many tries, this is not working as expected. There are files transfered today but with mod time previous yesterday.
# find ${var_dir} -maxdepth 1 -daystart -mtime +1 \( ! -iname "transfer_*" \) -exec mv '{}' "${var_dir}/${today}" \;
cd ${var_dir}/
tar czf transfers_${today}.tgz ${today}
cd -
chown ftg.ftg ${var_dir}/transfers_${today}.tgz
rm -rf ${var_dir}/${today}
# Replace "mv '{}' /opt/FTG/" to "rm '{}'"
find ${var_dir}/ -maxdepth 1 -daystart -mtime +6 -exec mv '{}' /opt/FTG/\;