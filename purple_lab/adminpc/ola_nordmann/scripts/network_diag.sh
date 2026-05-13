#!/bin/bash
echo "Tester nettverk..."
ip a
ip r
ping -c 3 8.8.8.8
