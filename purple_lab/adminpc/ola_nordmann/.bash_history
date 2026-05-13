cd /var/log
tail -f syslog
ssh drift@172.20.0.10
sudo systemctl restart smb
ping 172.21.0.40
