#!/bin/bash

set -o nounset
set -o errexit

RootPart=$(mount | fgrep 'on / ' | cut -d' ' -f1)

GrubCore=""

for Tmp in /boot/grub{2,}/i386-pc/core.img
do
    if test -f "$Tmp"; then
	GrubCore="$Tmp"
	break
    fi
done

if [ "$GrubCore" != "" ]; then
    echo "found grub core at $GrubCore"
else
    echo "couldn't find grub core.img file"
    exit 1
fi

for Tmp in grub2-install grub-install
do
    if GrubInstall=$(which "$Tmp" 2>/dev/null); then
	break
    fi
done

if [ "$GrubInstall" != "" ]; then
    echo "found install at $GrubInstall"
else
    echo "couldn't find grub install executable"
    exit 2
fi

echo "root on $RootPart"

read -p  "proceed? (y/[n]): " x

if [ "$x" != "y" ]; then
    echo "aborted"
    exit 1
fi

sudo -v
set -x
sudo chattr -i "$GrubCore"
sudo $GrubInstall --target=i386-pc --debug --force "$RootPart"
sudo chattr +i "$GrubCore"
