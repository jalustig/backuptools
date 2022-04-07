# A script that runs on your local backup server, which checks when backups were last run.
# Set it to run weekly with cron, and it'll email you if there are ever any problems e.g. one of the backups failed to run.

currtime=`date +%s`

EMAIL_ADDRESS="myemailaddress@gmail.com"

week=604800
month=2592000

problem=0
output="THERE ARE PROBLEMS!!

"
good_output="EVERYTHING LOOKS GOOD...


"

# check my backup to see when it was last completed
file="personal-backup.last"
lasttime=`stat -c %Y /home/borg/status/$file`
diff=$(( (currtime - lasttime) ))
lastdate=`date -d @$lasttime`

if [ $diff -gt $week ]; then
        problem=1
        output+="Personal computer needs to be backed up; last backup: $lastdate


"
else
	good_output+="Personal computer last backup: $lastdate


"
fi


# check file storage SSD backup

file="file-storage-backup.last"
lasttime=`stat -c %Y /home/borg/status/$file`
diff=$(( (currtime - lasttime) ))
lastdate=`date -d @$lasttime`

if [ $diff -gt $month ]; then
        problem=1
        lastdate=`date -d @$lasttime`
        output+="File storage SSD needs to be backed up; last backup: $lastdate


"
else
	good_output+="File storage SSD last backup: $lastdate


"
fi


# check server backup
file="server-backup.last"
lasttime=`stat -c %Y /home/borg/status/$file`
diff=$(( (currtime - lasttime) ))
lastdate=`date -d @$lasttime`

if [ $diff -gt $week ] ; then
        problem=1
        lastdate=`date -d @$lasttime`
        output+="server needs to be backed up; last backup: $lastdate


"
else
	good_output+="server last backup: $lastdate


"

fi

# check prune

file="prune.last"
lasttime=`stat -c %Y /home/borg/status/$file`
diff=$(( (currtime - lasttime) ))
lastdate=`date -d @$lasttime`

if [ $diff -gt $month ]; then
        problem=1
        lastdate=`date -d @$lasttime`
        output+="backups need to be pruned; last prune: $lastdate


"
else
	good_output+="last prune: $lastdate
	
"
fi


if [ $problem -eq 1 ]; then

	echo -e "${output}" | mail -s "Backups need to be checked!" $EMAIL_ADDRESS
	printf '%s' "${output}"
else
	## send email to say everything is good, on the first of the month
	DOM=$(date +%d)

	echo "no problems!"
	if [ $DOM -eq "01" ]; then
		echo "sending email.."
		echo -e "${good_output}" | mail -s "Backups all look good!" $EMAIL_ADDRESS
	fi
	printf '%s' "${good_output}"
	
fi
