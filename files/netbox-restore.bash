#!/bin/bash
#https://www.postgresql.org/docs/12/app-pg-dumpall.html
#https://netbox.readthedocs.io/en/stable/administration/replicating-netbox/

print_usage_and_exit() {
  echo "USAGE: netbox-restore /path/to/backup-filename.tar.gz  /path/to/restore/directory"
  echo "The backup-filename archive can be anywhere that is currently accessible."
  echo "The backup archive is assumed to be in the format netbox-backup-YYYY-MM-DD--HH-MM.tar.gz"
  echo "This script will look in $PWD and attempt to locate a valid if it is not provided on the commandline."
  echo "The restore directory can by anywhere accessible."
  echo "The restore directory is assumed to $PWD/netbox_restore if this is not provided on the commandline."
  exit 1
}

if [ -n "$1" ]; then
  VAR_FILE=$1
else
  #attempt to set a sane default
  VAR_FILE=$(ls -1 $PWD | grep "netbox-backup-....-..-.." | sort -r | head -n 1)
  echo "setting a default value for the restore file to $VAR_FILE as one was not passed in as an argument..."
  sleep 1
fi

if [ -n "$2" ]; then
  if [ -d $2 ]; then
    VAR_RESTORE_DIR="$2"
  else
    echo -e "ERROR: $2 is not a valid directory.\n"
    print_usage_and_exit
  fi
else
  #attempt to set a sane default
  VAR_RESTORE_DIR="$PWD/netbox_restore"
  sleep 1
fi

#these are taken from the backup script
VAR_NB_DIR="/opt/netbox/netbox"
VAR_NGINX_DIR="/etc/nginx/sites-available"

#some preliminary checks -- mostly for security reasons
if [ ! -f "$VAR_FILE" ]; then
  print_usage_and_exit
fi

if [ ${#VAR_FILE} -gt 7 ]; then
  if [ "${VAR_FILE: -7}" != ".tar.gz" ]; then
    echo "${VAR_FILE: -7}"
    echo "ERROR: a backup file created with the backup script should end in .tar.gz\n"
    print_usage_and_exit
  fi
else
  echo -e "ERROR: the filename suggests this is not a valid tar.gz file as the backup script creates files ending in .tar.gz\n"
  print_usage_and_exit
fi

echo -e "validating file..."
tar -xvzf $VAR_FILE -O > /dev/null
if [ $? -gt 0 ]; then
  exit 1
fi
echo -e "\n"

if [ ! -d $VAR_NB_DIR ]; then
  echo "ERROR: $VAR_NB_DIR directory is missing.  Is netbox installed?"
  exit 1
else
  echo -e "verified target netbox directory ($VAR_NB_DIR)...\n"
fi

if [ ! -d $VAR_NGINX_DIR ]; then
  echo "ERROR: $VAR_NGINX_DIR dirctory is missing.  Is ngnix installed?"
  exit
else
  echo -e "verified target nginx directory ($VAR_NGINX_DIR)...\n"
fi



if [ ! -d $VAR_RESTORE_DIR ]; then
  echo -e "creating restore directory...\n"
  mkdir -p $VAR_RESTORE_DIR
else
  echo -e "restore directory found...\n"
fi

echo -e "uncompressing archive to restore directory...\n"
#remove redundant working directories that were preserved when the archive was created
tar xzf $VAR_FILE -C $VAR_RESTORE_DIR --strip-components 2

ls -lah $VAR_RESTORE_DIR

echo -e "\nrestoring 'netbox' nginx configuration file to $VAR_NGINX_DIR ...\n"
sudo mv $VAR_RESTORE_DIR/netbox $VAR_NGINX_DIR/
sudo chown www_user:www_user $VAR_NGINX_DIR/netbox
sudo chmod   $VAR_NGINX_DIR/netbox
ls -lah $VAR_NGINX_DIR/netbox

echo -e "\nrestoring 'configuration.py' to $VAR_NB_DIR ...\n"
sudo mv $VAR_RESTORE_DIR/configuration.py $VAR_NB_DIR/
sudo chown netbox:netbox $VAR_NB_DIR/configuration.py
sudo chmod   $VAR_NB_DIR/configuration.py
ls -lah $VAR_NB_DIR/configuration.py

echo -e "\nrestoring 'media'directory to $VAR_NB_DIR ...\n"
sudo tar xzf $VAR_RESTORE_DIR/netbox-files-all.tar.gz -C $VAR_NB_DIR --strip-components 1
sudo chown -R netbox:netbox $NAR_NB_DIR/media
sudo chmod -R   $NAR_NB_DIR/media
ls -lahd $VAR_NB_DIR/media
ls -lah $VAR_NB_DIR/media
rm $VAR_RESTORE_DIR/netbox-files-all.tar.gz

echo -e "\nstopping netbox services ...\n"
service netbox-rq stop
service netbox stop

echo -e "\nrestoring the postgres database(s) ...\n"
su - postgres -c 'psql -c "drop database netbox"'
su - postgres -s 'psql -c "create database netbox"'
su - postgres -c psql < $VAR_RESTORE_DIR/postgresdump-all.sql
rm $VAR_RESTORE_DIR/postgresdump-all.sql

echo -e "\nresuming netbox services ...\n"
service netbox start
service netbox-rq start

echo -e "cleaning up...\n"
ls -lah $VAR_RESTORE_DIR

rmdir $VAR_RESTORE_DIR

