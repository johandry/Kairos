#!/usr/bin/env bash

#=======================================================================================================
# Author: Johandry Amador 
# Title:  DB and App helper.
# Description: DB and Application helper to create the database, fill out the development database, update or install the application and create models, views and controllers.
#=======================================================================================================

#=======================================================================================================
# TODO: The central script (named like the applicacion: FTG.sh) will have an option to upgrade the application. Upgrade Dancer, Bootstrap, ...
# 
#=======================================================================================================

############################################# GLOBAL VAR ###############################################

VERSION=1.0

declare -r DANCER_BIN_DIR="$( cd "$( dirname "$0" )" && pwd )"
declare -r DANCER_BASE_DIR="$( dirname ${DANCER_BIN_DIR} )"
declare -r DANCER_DB_DIR="${DANCER_BASE_DIR}/db"
declare -r DANCER_ENV_DIR="${DANCER_BASE_DIR}/environments"
declare -r DANCER_PUBLIC_DIR="${DANCER_BASE_DIR}/public"
declare -r DANCER_VIEWS_DIR="${DANCER_BASE_DIR}/views"
declare -r DANCER_TMP_DIR="${DANCER_BASE_DIR}/tmp"
declare -r DANCER_LOG_DIR="${DANCER_BASE_DIR}/logs"
declare -r DEFAULT_ENVIRONMENT="development"

########################################### GLOBAL FUNCTIONS ###########################################

error () {
  echo -e "\e[00;31mERROR: \e[00m${1}" >&2
  [[ ${2} ]] || exit 1
} 

warn () {
  echo -e "\e[01;33mWARNING: \e[00m${1}" >&2
}

info () {
  echo -e "${1}"
}

debug () {
  echo -e "Debug: ${1}"
}

Yes () {
  read -e -p "${1} " -i "Yes " -r
  [[ $REPLY =~ ^Yes$ ]]
}

############################################ VALIDATIONS  ##############################################

[[ ! -e "${DANCER_BASE_DIR}/config.yml" ]] && error "Directory '$DANCER_BASE_DIR' doesn't look like a Dancer directory."
[[ ! -d "${DANCER_BIN_DIR}" ]]             && error "Can't find Dancer's 'bin' directory in '${DANCER_BASE_DIR}'"
[[ ! -d "${DANCER_DB_DIR}" ]]              && error "Can't find Dancer's 'db' directory in '${DANCER_BASE_DIR}'"
[[ ! -d "${DANCER_ENV_DIR}" ]]             && error "Can't find Dancer's 'environments' directory in '${DANCER_BASE_DIR}'"
[[ ! -d "${DANCER_PUBLIC_DIR}" ]]          && error "Can't find Dancer's 'public' directory in '${DANCER_BASE_DIR}'"
[[ ! -d "${DANCER_VIEWS_DIR}" ]]           && error "Can't find Dancer's 'views' directory in '${DANCER_BASE_DIR}'"
[[ ! -d "${DANCER_LOG_DIR}" ]]            && error "Can't find Dancer's 'logs' directory in '${DANCER_BASE_DIR}'"

[[ ! -d "${DANCER_TMP_DIR}" ]]             && mkdir "${DANCER_TMP_DIR}"

# [[ ! -e "${DANCER_PUBLIC_DIR}/bootstrap/js/bootstrap.js" ]] && error "Can't find Bootstrap. Install it with 'FTG.sh --bundle'."
# [[ ! -e "${DANCER_PUBLIC_DIR}/font-awesone/css/font-awesome.css" ]] && error "Can't find Font-awesone. Install it with 'FTG.sh --bundle'."
# [[ ! -e "${DANCER_PUBLIC_DIR}/fullcalendar/fullcalendar/fullcalendar.js" ]] && error "Can't find Fullcalendar. Install it with 'FTG.sh --bundle'."

########################################################################################################

list_environments () {
  ls ${DANCER_ENV_DIR}/*.yml | sed 's/.*\/environments\/\(.*\)\.yml/  * \1/'
}

exists_environment? () {
  if [[ -z "${1}" || ! -e "${DANCER_ENV_DIR}/${1}.yml" ]]; then
    error "Environment '${1}' is not recognized. The valid environments are:" 0
    list_environments 
    exit 1
  fi
  return 0
}

exists_db? () {
  [[ -e "${DANCER_DB_DIR}/${1}.db" ]]
}

########################################################################################################

usage () {
  declare -r scriptName=${0##*/}
  cat <<EOF
${scriptName} is a script to startup the application.
Options:
  --help           or -h                    : Print this help.
  --version        or -v                    : Print version.
  --db:create      or -c [environment]      : Create the database. By default will create the ${DEFAULT_ENVIRONMENT} database.
  --db:seed        or -s                    : Seed or fill out the development database.
  --db:drop        or -d [environment]      : Delete the database. By default will drop the ${DEFAULT_ENVIRONMENT} database.
  --db:export      or -e [environment]      : Export or dump the database to a SQL file which includes tables creation and inserts. By default will export the ${DEFAULT_ENVIRONMENT} database.
  --db:restore     or -r [environment]      : Restore the database from a dump. By default will export the ${DEFAULT_ENVIRONMENT} database.
  --db:backup [environment]                 : Backup the database. By default will backup the ${DEFAULT_ENVIRONMENT} database.
  --bundle         or -b                    : TODO: Install or updates all the modules and dependencies.
  --app:controller or -C name               : TODO: Create a new controller.
  --app:view       or -V name               : TODO: Create a new view.
  --app:model      or -M name               : TODO: Create a new model.
  --app:scaffold   or -S name               : TODO: Create a new controller, view and model.
  --host:add       or -a user@hostname      : Allow connection between this server and hostname using user. Send the public key to the user home dierctory at hostname. 
  --host:addall    or -A                    : Send the public key to all the host. May cause a duplicate public key.
  --job:force      or -f id                 : Force Start the Job with the specified id
  --start [environment[:port]]              : Start the application using a defined environment and a port, if it is not set in the configuration file. By default the environment will be ${DEFAULT_ENVIRONMENT} using the port defined in ${DANCER_ENV_DIR}/${DEFAULT_ENVIRONMENT}.yml.
  --stop                                    : Stop the application.
  --status                                  : Report the status of the application, the port and the PID if running.
  --taillog                                 : Open the log file and keep it open.
EOF
}

########################################################################################################

db_backup () {
  declare -r environment=${1}

  exists_environment? "${environment}"

  if exists_db? "${environment}"; then
    info "Backing up the database for ${environment}."
    cp "${DANCER_DB_DIR}/${environment}.db" "${DANCER_DB_DIR}/${environment}.$(date +%y%m%d%H%M).db"
    [[ "${2}" == "DELETE" ]] && warn "Deleting the database for ${environment}." && rm -f "${DANCER_DB_DIR}/${environment}.db"  
  else
    error "Database for ${environment} was not found."
  fi
}

########################################################################################################

db_drop () {
  exists_environment? "${1}"

  exists_db? "${1}" && rm -f "${DANCER_DB_DIR}/${1}.db" && return

  error "Database for '${1}' was not found."
}

########################################################################################################

db_create () {
  declare -r environment=${1}

  exists_environment? "${environment}"

  [[ ! -e "${DANCER_DB_DIR}/${environment}.init.sql" ]] && error "Initializer file '${DANCER_DB_DIR}/${environment}.init.sql' not found."

  exists_db? "${environment}" && db_backup "${environment}" "DELETE"
  echo

  sqlite3 "${DANCER_DB_DIR}/${environment}.db" < "${DANCER_DB_DIR}/${environment}.init.sql" || error "Database for '${environment}' could not be initialized."

  info "The following tables have been created:"
  sqlite3 "${DANCER_DB_DIR}/${environment}.db" .tables
}

########################################################################################################

db_seed () {
  declare -r environment="development" # Only development is seeded.

  [[ ! -e "${DANCER_DB_DIR}/${environment}.seed.sql" ]] && error "Seeder file '${DANCER_DB_DIR}/${environment}.seed.sql' not found."  

  # If the DB do not exists then create it. If not, back it up
  if exists_db? "${environment}"; then 
    db_backup "${environment}"
    echo
  else
    db_create "${environment}"
    echo
  fi

  sqlite3 "${DANCER_DB_DIR}/${environment}.db" < "${DANCER_DB_DIR}/${environment}.seed.sql"

  info "The ${environment} database was sucessfuly seeded."
}

########################################################################################################

db_export () {
  declare -r environment=${1}

  exists_environment? "${environment}"
  exists_db? "${environment}" || error "Database for '${environment}' not found."

  sqlite3 "${DANCER_DB_DIR}/${environment}.db" .dump > "${DANCER_DB_DIR}/${environment}.dump.sql" || error "Database for '${environment}' could not be dumped."

  info "The '${environment}' database was sucessfuly dumped to '${environment}.dump.sql'."
}

########################################################################################################

db_restore () {
  declare -r environment=${1}

  exists_environment? "${environment}"

  # If the DB exists then backup it up.
  exists_db? "${environment}" && db_backup "${environment}" "DELETE" && echo

  sqlite3 "${DANCER_DB_DIR}/${environment}.db" < "${DANCER_DB_DIR}/${environment}.dump.sql" || error "Database for '${environment}' could not be restored."

  info "The '${environment}' database was sucessfuly restored from '${environment}.dump.sql'."
}

########################################################################################################

download () {
  wget --no-verbose --no-check-certificate -O "${1}" "${2}" 2>/dev/null || error "Could not download ${1}"
  # if which wget > /dev/null; then
  #   wget --no-verbose --no-check-certificate -O "${1}" "${2}" || error "Could not download ${1}"
  # elif which curl > /dev/null; then
  #   curl --location --silent --show-error --insecure --output "${1}" "${2}" || error "Could not download ${1}"
  # else
  #   error "Can't find wget or curl, needed to download updates."
  # fi
}

########################################################################################################

get_package () {
  declare -r package=${1%%,*}
  declare -r url=${1##*,}

  cd "${DANCER_PUBLIC_DIR}"
  [[ -d ${package} ]] && warn "Creating backup of previous ${package}." && mv ${package} "${package}.$(date +%y%m%d%H%M)"
  mkdir -p ${package}
  cd ${package}
  download ${package}.zip ${url}
  unzip -q ${package}.zip || error "Unzipping ${package}.zip"
  rm -f ${package}.zip
  info "Updated ${package}"
  echo 
}

########################################################################################################

get_module () {
  info "Getting module ${1}"
  cpanm ${1}
  # if which cpanm > /dev/null; then
  #   cpanm ${1}
  # elif which cpan > /dev/null; then
  #   cpan -i ${1}
  # else
  #   perl -MCPAN -e "install ${1}" || error "Can't install module ${1}"
  # fi 
}

########################################################################################################

bundle () {  
  if [[ -e "${DANCER_BASE_DIR}/Modfile" ]]; then
    while read dependency; do
      if [[ ! ${dependency} =~ ^# ]]; then 
        if [[ ${dependency%% *} == "cpan" ]]; then 
          get_module  ${dependency##* }
        elif [[ ${dependency%% *} == "pack" ]]; then
          get_package ${dependency##* }
        fi
      fi
    done < "${DANCER_BASE_DIR}/Modfile"
  fi

  # cpan -O > "${DANCER_TMP_DIR}/CPANOutdated"
  # if Yes "There are $(cat ${DANCER_TMP_DIR}/CPANOutdated | sed '1,5d' | wc -l) Perl modules. Do you like to update them?: "; then
  #   # Update all the Perl modules
  #   warn "This may take a while!"
  #   perl -MCPAN -e "upgrade /(.\*)/"
  # fi
}

########################################################################################################

start () {
  [[ -e "${DANCER_TMP_DIR}/pid" ]] && error "FTG is already running."

  declare -r environment=${1##*:}
  # declare -r port=${1%%:*}
  # declare params="--environment=${environment}"

  # [[ ${port} != ${environment} ]] && params="${params} --port=${port}"

  nohup "${DANCER_BIN_DIR}/server.pl" >> "${DANCER_LOG_DIR}/${environment}.log" 2>&1 &
  echo $! > "${DANCER_TMP_DIR}/pid"
  info "FTG is \e[01;32mRUNNING\e[00m in ${environment} with PID '$(cat "${DANCER_TMP_DIR}/pid")'."
}

########################################################################################################

stop () {
  [[ ! -e "${DANCER_TMP_DIR}/pid" ]] && error "FTG is not running."
  kill -9 $(cat "${DANCER_TMP_DIR}/pid")
  rm -f "${DANCER_TMP_DIR}/pid"
  warn "FTG has been \e[01;31mSTOPPED\e[00m."
}

########################################################################################################

status () {
  [[ -e "${DANCER_TMP_DIR}/pid" ]] && echo -e "\e[01;32mRUNNING\e[00m with PID '$(cat "${DANCER_TMP_DIR}/pid")'" && return
  echo -e "\e[01;31mSTOPPED\e[00m"
}

########################################################################################################

taillog () {
  tail -f "${DANCER_LOG_DIR}/${1}.log"
}

########################################################################################################

force () {
  [[ -z ${1} ]] && error "Provide a Job ID."
  declare -r id=${1}

  info "\e[01;32mSTARTING\e[00m Job with ID ${id}"
  "${DANCER_BIN_DIR}/execute.pl" ${id}
}

########################################################################################################

addHost () {
  [[ -z ${1} ]] && error "Provide a hostname."
  declare -r userAThostname=${1}

  [[ ! -e ~/.ssh/id_rsa.pub ]] && ssh-keygen
  [[ ! -e "${DANCER_DB_DIR}/authorized_keys" ]] && cp ~/.ssh/id_rsa.pub "${DANCER_DB_DIR}/authorized_keys"

  ssh-copy-id -i ~/.ssh/id_rsa.pub ${userAThostname}
}

########################################################################################################

addAllHosts () {
  echo "SELECT name FROM Containers;" | \
  sqlite3 db/development.db | \
  cut -d':' -f 1 | \
  while read uh
    do 
    h=`echo $uh | cut -d'@' -f 2`
    ip=`echo "SELECT ip FROM Machines WHERE hostname='$h';" | sqlite3 db/development.db`
    u=`echo $uh | cut -d'@' -f 1`
    newUH="${u}@${ip}"
    if [[ "${u}" != "dummyuser" ]]; then
      echo "Sending key to ${uh}"
      addHost ${newUH}
    fi
  done
}

########################################################################################################

model () {
  [[ -z ${1} ]] && error "Provide a name."
  declare -r name=${1}

  info "Creating the table for ${name}." && echo

  echo ""                                                                >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "/*"                                                               > "${DANCER_TMP_DIR}/${name}.sql"
  echo "TABLE: Credentials"                                              >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "DESC:  It is a unix user that may be associated to a real user." >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "*/"                                                              >> "${DANCER_TMP_DIR}/${name}.sql"
  echo ""                                                                >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "CREATE TABLE IF NOT EXISTS Credentials ("                        >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "  id    INTEGER PRIMARY KEY AUTOINCREMENT    NOT NULL,"          >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "  name          TEXT      NOT NULL,"                             >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "  othertable_id INTEGER,"                                        >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "  description   TEXT,"                                           >> "${DANCER_TMP_DIR}/${name}.sql"
  echo "  FOREIGN KEY(some_id) REFERENCES OtherTable(id)"                >> "${DANCER_TMP_DIR}/${name}.sql"
  echo ");"                                                              >> "${DANCER_TMP_DIR}/${name}.sql"

  warn "Edit the table before create the model:" && sleep 15s
  vim "${DANCER_TMP_DIR}/${name}.sql"

  sqlite3 "${DANCER_DB_DIR}/${DEFAULT_ENVIRONMENT}.db" < "${DANCER_TMP_DIR}/${name}.sql"

  cat "${DANCER_TMP_DIR}/${name}.sql" >> "${DANCER_DB_DIR}/${DEFAULT_ENVIRONMENT}.init.sql"

  rm -f "${DANCER_TMP_DIR}/${name}.sql"
}


########################################################################################################

controller () {
  [[ -z ${1} ]] && error "Provide a name."
  declare -r name=${1}

  
}

########################################################################################################

view () {
  [[ -z ${1} ]] && error "Provide a name."
  declare -r name=${1}

}

########################################################################################################

scaffold () {
  [[ -z ${1} ]] && error "Provide a name."
  declare -r name=${1}

  model "${name}"
  controller "${name}"
  view "${name}"
}

########################################################################################################

processOptions () {
  declare inputOptions
  declare -r scriptName=${0##*/}
  declare -r shortOpts="hvc::sd::e::r::ba:A"
  declare -r longOpts="help,version,db:create::,db:seed,db:drop::,db:export::,db:restore::,db:backup::,bundle,start,stop,status,taillog::,host:add:,host:addall"

  inputOptions=$(getopt -o "${shortOpts}" --long "${longOpts}" --name "${scriptName}" -- "${@}")

  if [[ ($? -ne 0) || ($# -eq 0) ]]; then
    echo
    usage
    exit 1
  fi

  eval set -- "${inputOptions}"

  while true; do
    case "${1}" in
      --help | -h)
        usage
        exit 0
        ;;

      --version | -v)
        echo "Version: ${VERSION}"
        exit 0
        ;;

      --db:create | -c)
        db_create "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;

      --db:seed | -s)
        db_seed
        exit 0
        ;;

      --db:drop | -d)
        db_drop "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;

      --db:export | -e)
        db_export "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;

      --db:restore | -r)
        db_restore "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;     

      --db:backup)
        db_backup "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;  

      # --bundle | -b)
      #   bundle "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
      #   exit 0
      #   ;;              

      --start)
        start "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;

      --stop)
        stop
        exit 0
        ;;        

      --status)
        status
        exit 0
        ;;           

      --taillog)
        taillog "${4:-${DEFAULT_ENVIRONMENT}}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;   

      --host:add | -a)
        addHost "${4}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;  

      --host:addall | -A)
        addAllHosts 
        exit 0
        ;;  

      --scaffold | -S)
        scaffold "${4}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;  

      --model | -M)
        scaffold "${4}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;   

      --controller | -C)
        scaffold "${4}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;  

      --view | -V)
        scaffold "${4}" # ${2} is empty and ${3} is '--'
        exit 0
        ;;                                   

      --) # Last parameter to parse
        exit 0
        ;;

      *)
        error "Unknown parameter ${1}"
        ;;
    esac
    shift
  done
}

################################################# MAIN #################################################

processOptions "${@}"

exit 0

########################################################################################################