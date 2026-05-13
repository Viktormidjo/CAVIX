#!/bin/bash
echo "Laster inn Graylog-konfigurasjon..."
mongorestore --archive=/graylog.dump --db=graylog
echo "Ferdig."
