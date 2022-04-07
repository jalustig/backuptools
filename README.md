# Custom Data Backup Tools with `Borgbackup`

This is a set of custom backup scripts that I put together in order to back up my personal and research data.

It's built on top of two main tools:

1. Borg backup
2. Borgmatic

The system is designed to back up data to a local NAS (e.g. a dedicated storage server or even an SSD attached to a Raspberry Pi) over SSH, and then upload the datastore offset. I used `rclone` to sync data to Google Drive, where I had unlimited storage. The bort datastore was fully encrypted at rest as well as when being sent to the local and online backup servers, so sending it over the web was not a problem.

The NAS can also be opened to SSH over the internet, which would allow you to backup your data when not at home.

## How it works

There are three key scripts that handle the backup, and run effectively in this order

1. `run-borgmatic.sh`, which manages actual backups to the server on your local network
2. `check-backup-status.sh`, which runs on the server and checks when the last backups were, to alert you if anything stops working.
3. `backup-offsite.sh`, which backups up the local borg datastore to an offsite location.

# Setup

1. Install borgbackup on your local machine (Linux or macOS), and create a NAS server with a headless borg client that can receive the data. I stored my data in an array attached to a Raspberry Pi, formatted with ZFS to enable compression as well as data integrity. To attach multiple SSDs to my Raspberry Pi, I used an external powered USB hub.
2. Set up borgbackup with a `borgmatic` script which will tell borg which data to backup, and where.
3. Open the NAS to the web with hardened SSH with public-key access only. Set up a static IP, or dyndns, to allow it to be reached no matter what.
4. Customize `run-borgmatic.sh` with the IP address of your data server, and set it to run on a cron script every 5 minutes.

## Design Considerations

### Why Borg backup?

I built my backup service on top of `borg` for a few reasons. First, it gave me full control over my backups, including encryption; second, it de-duplicates and compresses data. This was important because I want to make the most efficient possible use of my local storage.

### How to ensure that backups run regularly and correctly?

I created `run-borgmatic.sh` to run constantly, every few minutes through a cron script. However, I don't want to do a full backup all the time. Instead, the first thing that `run-borgmatic.sh` does is see if (a) another backup is currently running, or (b) if you recently backed up. It will wait until X amount of time (I set it for about 20 hours) before running another backup, after a first successful backup.

The effect of running it on a regular basis is that whenever you hop onto your computer, you will very shortly start a backup. If you set your backup script to run every day at 9am, for instance, or at a time in the evening when you aren't using your computer so heavily, your may or may not actually be on/open/awake.

### What about backing up multiple computers to the same data store, in order to take full advantage of borg's de-duplication?

This was one of the key considerations when I began this project, actually. I had been using Arq for backup, and it worked well for the most part, but I wanted to back up multiple computers and de-duplicate against them. For instance, I might share a folder with my wife over Dropbox, or photos via iCloud photo library, so the data in those folders will be mostly identical due to syncing. When storing backups of both computers to the cloud, that data is duplicated. I initially designed the backup system to allow for a single backup store for all computers, which would allow the de-duplication of this data across computers. However, Borg is not designed to allow for this functionality and it was necessary to run cross-checks for lock files stored on the server. I ultimately decided this made the system prone to failure and moved to separate data stores.

What I *did* do successfully was de-duplicate across multiple data sources in my local computer. If I use an external SSD to archive data from previous projects, I can copy that data to the external drive. When I then back up the external drive (to the same datastore that holds the backup data from my main computer), it will then de-duplicate the data between the computer and the external SSD. Note: you should set different backup prefixes for your external SSD backup and your main computer's data backup, so that they can be pruned correctly.

### Can I use ZFS de-duplication?

ZFS has the ability to de-duplicate data, but it won't help too much with backup data repositories, because this data is encrypted and compressed to begin with. Additionally, ZFS de-duplication is notoriously RAM hungry. I wouldn't recommend it in any case.