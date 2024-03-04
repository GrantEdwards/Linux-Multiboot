#!/bin/bash

set -x
dd if=mbr.img of=/dev/sda bs=512
dd if=bios-boot.img of=/dev/sda1 bs=64K
