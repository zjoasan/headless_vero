#!/bin/bash
#Install OSMC smb, with share on automounted drives
sudo apt-get install smb-app-osmc

# Setup configure and autostart wsdd service, to announce the machine on windows network
wget https://mirror.accum.se/debian/pool/main/w/wsdd/wsdd_0.7.0-2.1_all.deb
sudo apt install ./wsdd_0.7.0-2.1_all.deb
echo "WSDD_PARAMS=\"--interface "$(ip route get 8.8.8.8 | awk -- '{printf $5}')" -4\"" > ./wsdd.conf
sudo cp ./wsdd.conf /etc
sudo systemctl enable wsdd.service
sudo systemctl start wsdd.service
rm ./wsdd.conf

#Adding osmc as a smbuser, where user choses password
while true; do
    read -s -p "Enter smb-password: " SP1
    echo
    read -s -p "Repeat smb-password: " SP2
    echo

    if [[ "$SP1" != "$SP2" ]]; then
        echo "Passwords do not match. Please try again."
    else
        break
    fi
done
echo -e "$SP1\n$SP1" | sudo smbpasswd -a osmc