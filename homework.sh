#!/bin/bash

# Notes:
# Set as a cron job for once per day to automatically execute.
# This should be run as root for the loggging functions
# This assumes that the zip, aws cli, and necessary mail packages are installed.
# This also assumes that you have an AWS CLI profile set.
# Ideally S3 life cycle rules would delete the old backups but I included a fall back to remove them as they expire.

# Set static variables
logfile='/var/log/backupscript.log';
targetfolder='/path/to/your/stuff';
bucketname='myawesomebucket'
useremail='alias@email.com'

# Set dynamic variables
zipfilelocation="/tmp/backup-$(date +"%m-%d-%y").zip";

# Create function to echo message and add to log
function log() {
    echo $1;
    echo $1 >> $logfile;
}

# Check if log file exists
if ! [ -f "$logfile" ]; then
    # If not then create it
    touch $logfile;
    # Set proper ownership and permissions
    chown root:root $logfile;
    chmod 744 $logfile;
fi;

# Create zip file
zip -r $zipfilelocation $targetfolder >/dev/null && log "$(date) - Zip Created" || log "$(date) - Zip Failed";

# Send zip file to bucket
aws s3 cp "$zipfilelocation" s3://$bucketname/backup-$(date +"%m-%d-%y").zip && log "$(date) - Uploaded zip file" || log "$(date) - Failed to upload zip file";

# Fall back remove backups from 8 days ago (if life cycle isn't set in S3)
aws s3 rm s3://$bucketname/backup-$(date --date="8 days ago" +"%d-%m-%y").zip 2>/dev/null && log "$(date) - Removed outdated zip file" || log "$(date) - Outdated zip file not found";
# This will remove backups as they expire

# Email status message
mail -s “Backup Summary” $useremail < $(tail $logfile) && log "$(date) - Sent email" || log "$(date) - Failed to send email";

# Delete local copy of backup file
rm -rf $zipfilelocation && log "$(date) - Cleanup complete" || log "$(date) - Cleanup failed $zipfilelocation";