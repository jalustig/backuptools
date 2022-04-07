#!/usr/local/bin/bash

# The central script that runs backups from your computer to the local server.
# Customize it with borgmatic yaml configuration files, as well as multiple potential sources of data
# (e.g. an external SSD)

export PATH=$PATH:/usr/local/bin/:/sbin/
BORG_RELOCATED_REPO_ACCESS_IS_OK=yes

FORCE=0
FORCE_PRUNE=0

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -f|--force)
      FORCE=1
      shift # past argument
      shift # past value
      ;;
    -fp|--force-prune)
      FORCE_PRUNE=1
      shift # past argument
      shift # past value
      ;;
  esac
done

DATE=`date`
echo "---------------------------------"
echo ""
echo "Main backup: Running at $DATE"
echo ""

currtime=`date +%s`

REPO_LOCATION="/storage/backup/borgbackup/username"

### 0. CHECK IF ON LOCAL NETWORK

IS_ON_WIFI=1
ping -q -c 1 backupserver.local > /dev/null || IS_ON_WIFI=0

if [ $IS_ON_WIFI -eq 0 ]; then
    # if we are on the internet, try to connect back home!
    SERVER="external-ip.remote" # the external IP of your local backup server
    echo "Not on local wifi"
else
    # if we are on local wifi, then connect to the local server without hopping on the internet
    SERVER="backupserver.local" # the internal IP address of your local backup server (static IP from router)
    echo "On local wifi"
fi


### -----------
### 0. CHECK IF BORG IS RUNNING

### CHECK AGAINST A LOCAL LOCK

# if borglock.lock is OLDER than 2 days-- just remove it
lockfile="/var/tmp/borglock.lock"
if [ -f $lockfile ]; then
    filemtime=`/usr/local/opt/coreutils/libexec/gnubin/stat -c %Y $lockfile`
    diff=$(( (currtime - filemtime) ))
    if [ $diff -gt 172800 ]; then
        echo "removing lockfile, which is old"
        rm -f - $lockfile
    fi
fi

exec 100>$lockfile || exit 0
flock -n 100 || exit 0

#### -----------
#### 1. FILE STORAGE, EXTERNAL SSD BACKUP

# the goal is to run the backup IMMEDIATELY if the drive is plugged in, to try to back up whenever I can
DRIVE_CONNECTED=1
df | /usr/bin/grep -e /Volumes/File\ Storage > /dev/null || DRIVE_CONNECTED=0

LAST_CONFIG2_RUN_FILE=~/.config/borg/status/config2-last-run

# only back up file store if we are local wifi
if [ $DRIVE_CONNECTED -eq 1 ] && [ $IS_ON_WIFI -eq 1 ]; then
    echo "file storage is attached"

    RUN_BACKUP=1


    # exit if the last time we ran the script was < 1 day ago
    filemtime=`/usr/local/opt/coreutils/libexec/gnubin/stat -c %Y $LAST_CONFIG2_RUN_FILE`
    diff=$(( (currtime - filemtime) ))

    RUN_BACKUP=1
    # don't run it if it's been less than 20h since the last backup 
    # (this allows me to run a backup 2 days in a row, if I run one in the afternoon on day 1,
    # then on day 2, I have the SSD plugged in during the morning- it might run again for more backups.)
    if [ $diff -lt 72000 ]; then
        echo "File Storage SSD: Last run was $diff seconds ago"
        if [ $FORCE -eq 0 ]; then
            RUN_BACKUP=0
        else
            echo "running anyway"
        fi
    fi

    if [ $RUN_BACKUP -eq 1 ]; then
        terminal-notifier -message 'Starting File Storage backup' -title 'Backup' -group 'borg.backup'

        CONFIG2_LOG=~/.config/borg/status/config2.log
        rm -f -- $CONFIG2_LOG
        borgmatic -v 2 create --config ~/.config/borgmatic.d/config2.yaml | tee -a $CONFIG2_LOG

        terminal-notifier -message 'Completed File Storage backup' -title 'Backup' -group 'borg.backup'

        ssh borg@$SERVER touch status/file-storage-backup.last
        touch $LAST_CONFIG2_RUN_FILE
    fi

else
    echo "File Storage SSD not connected, moving to main backup"
fi


#### -----------
#### MAIN SSD BACKUP

# the goal is to run the backup IMMEDIATELY when we turn on the computer, and then every 3 hours

LAST_CONFIG1_RUN_FILE=~/.config/borg/status/config1-last-run
# exit if the last time we ran the script was < 1 day ago
filemtime=`/usr/local/opt/coreutils/libexec/gnubin/stat -c %Y $LAST_CONFIG1_RUN_FILE`
diff=$(( (currtime - filemtime) ))

RUN_BACKUP=1
# don't run it if it's been less than 6h since the last backup
if [ $diff -lt 21600 ]; then
    echo "Main Computer SSD: last run was $diff seconds ago"
    if [ $FORCE -eq 0 ]; then
        RUN_BACKUP=0
    else
        echo "running anyway"
    fi
fi


if [ $RUN_BACKUP -eq 1 ]; then
    terminal-notifier -message 'Started backup' -title 'Backup' -group 'borg.backup'
    
    CONFIG1_LOG=~/.config/borg/status/config1.log
    
    rm -f -- $CONFIG1_LOG
    if [ $IS_ON_WIFI -eq 1 ]; then
        borgmatic -v 2 create --info --stats --config ~/.config/borgmatic.d/config1.yaml | tee -a $CONFIG1_LOG
    else 
        borgmatic -v 2 create --config ~/.config/borgmatic.d/config1.yaml --override location.repositories="['borg@$SERVER:$REPO_LOCATION',]" | tee -a $CONFIG1_LOG
    
    fi
    
    ssh borg@$SERVER touch status/my-backup.last
    
    terminal-notifier -message 'Completed backup' -title 'Backup' -group 'borg.backup'
    
    touch $LAST_CONFIG1_RUN_FILE
fi

#### ---------
#### Prune backups

LAST_PRUNE_RUN_FILE=~/.config/borg/status/prune-last-run
filemtime=`/usr/local/opt/coreutils/libexec/gnubin/stat -c %Y $LAST_PRUNE_RUN_FILE`
diff=$(( (currtime - filemtime) ))

RUN_PRUNE=1
# don't run it if it's been less than 1w since the last backup
if [ $diff -lt 605800 ]; then
    echo "Prune backups: last run was $diff seconds ago"
    if [ $FORCE_PRUNE -eq 0 ]; then
        RUN_PRUNE=0
    else
        echo "running anyway"
    fi
fi

# only prune if we are on local wifi. no need to do this on the web...
if [ $RUN_PRUNE -eq 1 ] && [ $IS_ON_WIFI -eq 1 ]; then
    terminal-notifier -message 'Started backup prune' -title 'Backup' -group 'borg.backup'
    
    PRUNE_LOG=~/.config/borg/status/prune.log
    CONFIG=~/.config/borgmatic.d/config1.yaml
    rm -f -- $PRUNE_LOG
    borgmatic -v2 list --config $CONFIG | tee -a $PRUNE_LOG
    /usr/local/bin/cronitor exec vb603f borgmatic -v 2 prune --info --stats | tee -a $PRUNE_LOG
    borgmatic -v2 list --config $CONFIG  | tee -a $PRUNE_LOG
    
    terminal-notifier -message 'Completed backup prune' -title 'Backup' -group 'borg.backup'
    
    ssh borg@$SERVER touch status/prune.last
    
    touch ~/.config/borg/status/prune-last-run
fi