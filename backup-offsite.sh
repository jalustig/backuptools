# A script that will back up your local ZFS store to an offsite location.
# Always back up your backups!

exec 100>/var/tmp/backup-offsite.lock || exit 0
flock -n 100 || exit 0

echo "setting permissions.."

~/set-backup-permissions.sh # set correct permissions to ensure everything will be accessible

echo "starting upload.."

rclone sync /storage/ OffsiteStorage:zfs-storage --verbose --progress
