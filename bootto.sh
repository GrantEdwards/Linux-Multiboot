#!/bin/bash

set -o nounset
set -o errexit

Titles=$(grep '^menuentry' grub/grub.cfg | sed 's/menuentry //g' | sed 's/{//g' | sed "s/'//g")

if [ $# = 0 ]; then
    echo "$Titles"
    exit 1
fi

N=$(echo "$Titles" | fgrep -i "$1" | wc -l)

if [ $N -eq 0 ]; then
    echo "didn't find grub boot entry with '$1' in title"
    exit 1
fi

if [ $N -gt 1 ]; then
    echo "ambiguous title pattern '$1':"
    echo "$Titles" | fgrep -i "$1"
    exit 1
fi

Default=$(echo "$Titles" | fgrep -n -i "$1" | cut -d: -f1)
Default=$((Default - 1))

echo "Setting default to $Default..."
sudo sed -i.bak "s/^default=.*/default=$Default/g" grub/grub.cfg
sleep 1
echo "Rebooting..."
sleep 1
sudo reboot

