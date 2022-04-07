# sets borg datastore to correct permissions, to ensure that everythign is accessible correctly.
# I found that borg would variously mess up the permissions on the files  

sudo find /storage/backup -type d -exec chmod 775 {} +
sudo find /storage/backup -type f -exec chmod 664 {} +
