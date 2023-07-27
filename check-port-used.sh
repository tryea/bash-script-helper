#!/bin/bash

echo "TCP ports in use:"
sudo netstat -tuln | grep tcp | awk '{print $4}' | cut -d: -f2

echo "UDP ports in use:"
sudo netstat -tuln | grep udp | awk '{print $4}' | cut -d: -f2
