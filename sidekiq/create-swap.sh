#!/bin/bash
dd if=/dev/zero of=/swapfile bs=1024 count=256k
mkswap /swapfile
swapon /swapfile
echo "/swapfile       none    swap    sw      0       0" | tee -a /etc/fstab
echo 20 | tee /proc/sys/vm/swappiness
echo vm.swappiness = 20 | tee -a /etc/sysctl.conf