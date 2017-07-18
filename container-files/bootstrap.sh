#!/bin/bash
set -eu
export TERM=xterm
# Bash Colors
green=`tput setaf 2`
bold=`tput bold`
reset=`tput sgr0`
# Functions
log() {
  if [[ "$@" ]]; then echo "${bold}${green}[VSFTPD `date +'%T'`]${reset} $@";
  else echo; fi
}

# If no env var for FTP_USER has been specified, use 'admin':
if [ "$FTP_USER" = "admin" ]; then
    export FTP_USER='admin'
fi

# If no env var has been specified, generate a random password for FTP_USER:
if [ "$FTP_PASS" = "random" ]; then
    export FTP_PASS=`cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c${1:-16}`
fi

# Do not log to STDOUT by default:
if [ "$LOG_STDOUT" = "false" ]; then
        export LOG_STDOUT=''
elif [ "$LOG_STDOUT" = "true" ]; then
        export LOG_STDOUT='Yes.'
else
  log "No LOG_STDOUT selected. System will crash"
  exit 1
fi

# Anonymous access settings
if [ "${ANONYMOUS_ACCESS}" = "true" ]; then
  sed -i "s|anonymous_enable=NO|anonymous_enable=YES|g" /etc/vsftpd/vsftpd.conf
  log "Enabled access for anonymous user."
fi

# Passive access settings
if [ ! "${PUBLICHOST}" = "ftp.foo.com" ]; then
  sed -i "s|pasv_address=|pasv_address=${PUBLICHOST}|g" /etc/vsftpd/vsftpd.conf
  log "Enabled passive address."
fi

# Local Root
sed -i "s|local_root=/home/vsftpd/'$USER'|local_root=${LOCAL_ROOT}|g" /etc/vsftpd/vsftpd.conf
log "Local root set."

# Xferlog File
sed -i "s|xferlog_file=/var/log/vsftpd/vsftpd.log|xferlog_file=${XFERLOG_FILE}|g" /etc/vsftpd/vsftpd.conf
log "Xferlog file set."

# Create home dir and update vsftpd user db:
#mkdir -p "/home/vsftpd/${FTP_USER}"
#log "Created home directory for user: ${FTP_USER}"

echo -e "${FTP_USER}\n${FTP_PASS}" > /etc/vsftpd/virtual_users.txt
log "Updated /etc/vsftpd/virtual_users.txt"

/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db
log "Updated vsftpd database"

# Get log file path
export LOG_FILE=`grep xferlog_file /etc/vsftpd/vsftpd.conf|cut -d= -f2`

# Set permissions for FTP user
#chown -R ftp:ftp /home/vsftpd/
chown ftp:ftp ${LOCAL_ROOT}
log "Fixed permissions for newly created user: ${FTP_USER}"

# stdout server info:
if [ ! $LOG_STDOUT ]; then
cat << EOB
	SERVER SETTINGS
	---------------
	· FTP User: $FTP_USER
	· FTP Password: $FTP_PASS
	· Log file: $LOG_FILE
EOB
else
    /usr/bin/ln -sf /dev/stdout $LOG_FILE
fi

log "VSFTPD daemon starting"
# Run vsftpd:
&>/dev/null /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
