#!/bin/bash

set -e

# Load config
source /etc/backup.conf

TMPDIR=/tmp/backup
mkdir -p "$TMPDIR"

# Clean old temp files
rm -f "$TMPDIR"/*

# Fetch files from SMB share
smbclient //$SMB_HOST/$SMB_SHARE -U admin%AdminPass123 \
  -c "lcd $TMPDIR; prompt off; recurse; mget *"

# Create ZIP inside TMPDIR
cd "$TMPDIR"
zip -r "$TMPDIR/$BACKUP_NAME" .

# Send ZIP to backup destination via SCP
sshpass -p "$BACKUP_PASS" scp \
  -o StrictHostKeyChecking=no \
  "$TMPDIR/$BACKUP_NAME" \
  $BACKUP_USER@$BACKUP_HOST:$BACKUP_DEST

# Clean up
rm -rf "$TMPDIR"
