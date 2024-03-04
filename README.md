
# Multiboot Example

This repo contains a few scripts and a sample config file which (along
with this README.md) demonstrate one way to multi-boot a bunch of Linux
distros from one drive. This example it will handle up to 9 different
distros.

## Why Boot 9 Distros?

I do this so that I have access to a variety of versions of different
distros for testing PCI boards and device drivers (and their Makefiles
and install scripts).  If you just want to test drive a bunch of
different distros, then using VMs is probably a better option. But, I
don't trust VMs for testing PCI boards and drivers. My customers are
almost never running VMs, so I don't do my testing in VMs.

## UEFI vs. Legacy

The obvious choice might seem to be to do it with UEFI and a nice boot
manager like rEFInd.  After spending some time reading about others'
attempts to multiboot many different distros with UEFI, I decided
against it.  There seemed to be chronic problems with

 1. One distro overwriting files belonging to another distro in the
    UEFI System Partition (ESP) during installation or upgrade.
    
 2. UEFI NVRAM ending up with confusing, duplicate, or missing
    options.
    
 3. Having to manually move, rename, delete, or edit files in the ESP
    after installing a new distro.

OTOH, it's fairly easy to do this with Legacy boot and Grub2, so
that's what is shown here.  It works pretty much the same with DOS
or GPT disklabels. I did it for many years with a DOS disklabel, but
I've recently switch to using a GPT disklabel — so that's what I'll
document and demonstrate here.

## Single Stage vs. Two Stage Boot

After deciding to do legacy boot with GPT disklabel, there's still the
choice of doing a single-stage boot or a two-stage boot.

### Single Stage Boot

In a single-stage boot setup, the instance of grub that starts from
the MBR has a configuration that presents to the user all of the
choices for all of the distros. Each distro might have several
different boot options (different kernels, different kernel arguments,
etc.).  In a single-stage boot setup, all of those options from all of
the distros are offered by a single grub menu (ideally with a submenu
for each distro). When the user makes a choice, grub then boots the
selected distro with the selected kernel and options.
 
This sounds nice, but in practice it doesn't "just work". Maintaining
that single grub configuration proves to be difficult as distros are
installed, upgraded, removed, overwritten, and kernels are
added/removed. The grub "OS Prober" feature tries to do that, but it
just doesn't work reliably enough for all distros, and the single flat
menu it produces is not at all friendly.

There is also a constant fight between distros over who owns the grub
configuration, so the menu is constantly being restyled and re-ordered
as distros are installed and upgraded.  You can work around that by
telling the distros to install grub to an unused disk and unused boot
partition, and then manually maintain the grub config that's used by
the MBR grub instance, but that's a lot of error-prone work.

### Dual Stage Boot

A dual stage boot avoids most of these problems. There is a "master"
grub instance that starts from the MBR and has a small stand-alone
grub-boot directory containing its manually maintained grub.cfg file
along with the various other grub resource and stage 2 files.

That master grub configuration knows nothing about the individual
Linux distros' boot choices. It simply uses the "chainloader" command
to boot whatever partition the user selects. That partition is
required to have a secondary bootloader (installed by that
partition's distro) that knows all about what choices are available
for that distro and how to boot those choices. [In practice, that
secondary bootloader is another copy of grub that is installed by the
distro itself.]

**NOTE:** **_The master grub instance that starts from the MBR does
not belong to, nor was it installed by, any of the distros in any of
the partitions._**

When a distro is installed, the bootloader for that distro is installed
_in the distro's partition_. There are some installers that don't
support this directly, so there is a somewhat hackish work-around
which will be explained later.

## Disk Layout

Here's the example GPT partition layout for a 1TB disk that will
support up to 9 Linux distros (each with a 100GB root partition). A
DOS disklabel layout would be the same except there would be no BIOS
Boot partition. With a DOS disk-label, there's a region of unused disk
space between the disk-label and the first partition that is used
instead for grub to store it's "core" image data.


~~~
         ┌──────────────────────────────┐
     MBR │           GPT+Grub           │
         ├──────────────────────────────┤
    sda1 │          BIOS Boot           │   2MB
         ├──────────────────────────────┤
    sda2 │             Grub             │  20MB
         ├──────────────────────────────┤
    sda3 │             swap             │  16GB
         ├──────────────────────────────┤
    sda4 │        Linux distro 1        │ 100GB
         ├──────────────────────────────┤
    sda5 │        Linux distro 2        │ 100GB
         ├──────────────────────────────┤
    sda6 │        Linux distro 3        │ 100GB
         ├──────────────────────────────┤
    sda7 │        Linux distro 4        │ 100GB
         ├──────────────────────────────┤
    sda8 │        Linux distro 5        │ 100GB
         ├──────────────────────────────┤
    sda9 │        Linux distro 6        │ 100GB
         ├──────────────────────────────┤
   sda10 │        Linux distro 7        │ 100GB
         ├──────────────────────────────┤
   sda11 │        Linux distro 8        │ 100GB
         ├──────────────────────────────┤
   sda12 │        Linux distro 9        │ 100GB
         ├──────────────────────────────┤
   sda13 │           scratch            │  15GB
         └──────────────────────────────┘
~~~

**sda1 — BIOS Boot** is where Grub's core.img file is stored by
`grub-install` when the master grub instance is installed in the MBR.

**sda2 — Grub** is where Grub's config and secondary files are stored
by `grub-install` when the master grub instance is installed in the
MBR.

**sda3 — swap** is the Linux swap partition that is used by all of the
installed Linux distros.

**sda4-12 — Linux distro N** are the 9 root partitions where 9
different Linux distros can be installed.

**sda13 — scratch** is a spare partition that can be used for sharing
data between distros (or whatever else you want).


## Initial Setup

### Partitions

Boot the computer using another device (e.g. live USB from whatever
distro you like) or a different drive. It doesn't really matter what
distro as long as it has a partitioning tool along with grub2 and the
the 'grub-install' command (AKA grub2-install on some distros).

 * Create the GPT disk label and partitions as shown.
 * Make sure that the BIOS Boot partition (sda1 above) has the type
   set to "BIOS boot"
 * Set the swap partition (sda3 above) type to "linux swap"
 * Set the rest of the partition types to "linux filesystem"
 
When you're done, it should look something like this:

~~~
$ sudo fdisk -l /dev/sda

Disk /dev/sda: 931.5 GiB, 1000204886016 bytes, 1953525168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: gpt
Disk identifier: 4F6BFBEA-968D-8A44-B0FC-7B83A6A798F1

Device          Start        End   Sectors  Size Type
/dev/sda1        2048       6143      4096    2M BIOS boot
/dev/sda2        6144      47103     40960   20M Linux filesystem
/dev/sda3       47104   33601535  33554432   16G Linux swap
/dev/sda4    33601536  243316735 209715200  100G Linux filesystem
/dev/sda5   243316736  453031935 209715200  100G Linux filesystem
/dev/sda6   453031936  662747135 209715200  100G Linux filesystem
/dev/sda7   662747136  872462335 209715200  100G Linux filesystem
/dev/sda8   872462336 1082177535 209715200  100G Linux filesystem
/dev/sda9  1082177536 1291892735 209715200  100G Linux filesystem
/dev/sda10 1291892736 1501607935 209715200  100G Linux filesystem
/dev/sda11 1501607936 1711323135 209715200  100G Linux filesystem
/dev/sda12 1711323136 1921038335 209715200  100G Linux filesystem
/dev/sda13 1921038336 1953523711  32485376 15.5G Linux filesystem
~~~

### Formatting

 * Format the sda2 grub partition as ext4 using mkfs.ext4.
 
 * Format the sda3 swap partition using mkswap.
 
 * If desired, format the sda13 scratch partition with whatever
   filesystem you want.
   
### Install Master Grub

 * Mount the sda2 grub partition somewhere it won't interfere with anything:  
 
        mkdir /mnt/mygrub
        mount /dev/sda2 /mnt/mygrub
   
 * Install grub to MBR and the partition mounted above.
 
        grub-install --boot-directory=/mnt/mygrub/grub /dev/sda
   
 * Copy the utility scripts to that grub partition and the grub.cfg
   file to the grub subdirectory.
   
        cp grub.cfg /mnt/mygrub/grub/
        cp bootto.sh grubinstll.sh restore.sh /mnt/mygrub/
   
 * Make backup images of the MBR and the BIOS boot partition.
 
        cd /mnt/mygrub
        dd if=/dev/sda of=mbr.img bs=512 count=1
        dd if=/dev/sda1 of=bios-boot.img bs=64k
   
You should end up with something like this in /mnt/mygrub:

~~~
$ ls -l

total 2065
-rw-r--r--. 1 root root 2097152 Feb 27 08:52 bios-boot.img
-rw-r-xr-x. 1 root root     682 Feb 27 11:51 bootto.sh
drwxr-xr-x. 6 root root    1024 Feb 28 17:26 grub
-rwxr-xr-x. 1 root root     854 Feb 27 11:43 grubinstall.sh
drwx------. 2 root root   12288 Feb 27 08:46 lost+found
-rw-r--r--. 1 root root     512 Feb 27 08:52 mbr.img
-rwxr-xr-x. 1 root root      93 Feb 27 08:57 restore.sh
~~~

The two backup image files (bios-boot.img and mbr.img) will be used
later to undo the damage done by evil distros that insist on
installing grub to the MBR and BIOS boot partition because the distro
developers want emulate Microsoft and believe that **_all your disk
are belong to us_**.  [Yes, we're talking about you, RedHat and
Ubuntu.]

### Master Grub Config

The master `grub.cfg` configuration lives in the 'grub' subdirectory
on sda2. It's pretty simple: it just allows the user to choose which
of the nine Linux partitions (or a second drive) to boot. Here's the
basic example configuration:

**`grub.cfg`**
~~~
timeout=10
default=0

drivemap -r

menuentry 'sda4' {
  chainloader (hd0,4)+1
}

menuentry 'sda5' {
  chainloader (hd0,5)+1
}

menuentry 'sda6' {
  chainloader (hd0,6)+1
}

menuentry 'sda7' {
  chainloader (hd0,7)+1
}

menuentry 'sda8' {
  chainloader (hd0,8)+1
}

menuentry 'sda9' {
  chainloader (hd0,9)+1
}

menuentry 'sda10' {
  chainloader (hd0,10)+1
}

menuentry 'sda11' {
  chainloader (hd0,11)+1
}

menuentry 'sda12' {
  chainloader (hd0,12)+1
}

menuentry ' '{
  true
}

menuentry 'hd1' {
  set root=(hd1)
  drivemap -s hd0 hd1
  chainloader +1
}
~~~

The last menu entry lets you boot the "other" hard drive (in my case
that's an m.2 flash drive on the motherboard). If you don't have an
hd1 drive, then you can delete that menu entry.

In my system, I edit the grub.cfg file as I add/remove distros so that
the menu tells me what distro is currently installed in each
partition. Here's a typical master grub menu on my system:

~~~
┌────────────────────────────────────────────────────────────────────────────────┐
│                                                                                │
│                             GNU GRUB  version 2.06                             │
│                                                                                │
│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│ │*sda4   Ubuntu Server 22.04.4                                               │ │
│ │ sda5   Ubuntu Server 20.04.6                                               │ │
│ │ sda6                                                                       │ │
│ │ sda7                                                                       │ │
│ │ sda8   Centos 7.9 minimal                                                  │ │
│ │ sda9   Rocky 8.9 minimal                                                   │ │
│ │ sda10  Rocky 9.3 minimal                                                   │ │
│ │ sda11  Mint 21.3 Mate                                                      │ │
│ │ sda12  OpenSuse Leap 15.5                                                  │ │
│ │                                                                            │ │
│ │ m.2 drive                                                                  │ │
│ │                                                                            │ │
│ │                                                                            │ │
│ └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│      Use the ↑ and ↓ keys to select which entry is highlighted.                │
│      Press enter to boot the selected OS, `e' to edit the commands             │
│      before booting or `c' for a command-line.                                 │
│                                                                                │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
~~~

## Installing Linux Distros

To install a Linux distro, boot from a live USB/DVD as usual. There
are a few things that need special attention during the installation.

### Disk Partitioning

You do _not_ want to "use the whole disk", or "automatically
partition", "shrink existing partitions", "make room for a new OS", or
anything that sounds remotely like any of those.

You want to manually control the partition choice and installation
layout. This may be called something like "advanced layout" or
"advanced partition" or "manual partitioning" or something similar.

Once you get to the manual partitioning menus/screens:

 * You do _not_ want to create any new partitions.
 
 * You do _not_ want to remove, shrink, or grow any existing
   partitions.

 * The _only_ existing partition you want to _format_ is the root
   partition (sda4-12) to which you're going to install the new
   distro.
   
 * You do _not_ want a separate boot partition or separate home
   partition. You want everything to be installed in the root
   partition.

You should end up with an installation map with nothing chosen except
that one partition mounted at "/". It should be formatted as Ext4 [why
will be explained below].

Avoid formatting the swap partition if possible. If the distro allows
you to select the swap partition and mount/use it as "swap" without
formatting it, do that. If the distro insists it wants to format the
partition you've selected as "swap", then unselect it. In almost all
cases the existing swap partition will get used as swap without you
having to select it during installation.

Again: there should be only _one_ partition that's going to be
_formatted_: the root partition (sda4-12) where we're installing the
new distro.

If you want, you can configure other partitions (e.g. the scratch
partition sda13) to be _mounted_ in various places in the root
filesystem, _but don't format them_.  It can be convenient to have
sda2 (the master grub partition) mounted, but don't mount it anywhere
under /boot.  Mount it somewhere like /mnt/mygrub.


### Root Filesystem Type

In order for the distro's grub to be installed in the distro's root
partition, grub will have to use a block-list to read its core.img
file. With an _**MBR**_ installation (like the master grub), that file
is read from either

 1. The gap between the DOS disklabel and the first partition, or
 2. The BIOS Boot partition (when GPT disklabel is used).
 
For a _**partition**_ installation, the core.img file has to be read from
its location under /boot/grub in the distro's root filesystem. Since
the MBR can only hold a few hundred bytes of code, there's no way it
can understand a modern Linux filesystem. Instead, grub-install will
write into the MBR a list of raw disk-block indexes where the data for
core.img is stored in that root filesystem. If those blocks move after
grub is installed, the code in the MBR won't know about it, and the
partition will stop booting.
   
Therefore, you must choose a filesystem for the distro's root partition
that allows a file's data blocks to be locked in place using the
`chattr +i` command which makes a file immutable. The Ext4 filesystem
will not move the data blocks of an immutable file. _That may not be
true of more "advanced" filesystems like ZFS or BTRFS._ There's no
requirement that the data blocks of an immutable file can't be moved
around by the filesystem during its internal housekeeping. The
requirement is that _user_ programs can't modify an immutable
file. The design of Ext2/3/4 is such that the data blocks of an
immutable file will not move. I suspect that's not true of filesystems
that support things like copy-on-write snapshots etc.

I always choose Ext4.

### Bootloader Install Destination

If you can, choose to install the bootloader to the distro's root
partition. All distros used to offer this choice, but the more
Borg-like ones (RedHat and Ubuntu) have stopped offering a choice:
they will always install the bootloader to the MBR and attempt to take
over the entire boot process. OpenSuse and Mint still play nicely with
others.

When installing a Borg distribution, you don't get a choice, so let it
install the bootloader to the MBR — you'll fix it later.

### OS Prober

If you're offered the choice during installation, disable the Grub2 OS
Prober. It doesn't produce anything useful, but at least it takes a
long time. It used to be common for installers to offer this choice,
but most now don't let you choose and just enable it without asking
[though Unbutu 22 has disabled it].

## Post Install

If the distro that you just installed allowed you to install the
bootloader to the distro's root partition, then after rebooting you
will see the expected "master grub" menu. You can select the partition
containing the new distro and boot it. Once it's booted you can skip
the Un-Borging section and go to Installed System Tweaks.

If the distro that you just installed didn't give you a choice for
bootloader destination, then it installed to the MBR and Bios Boot
partition. After rebooting you won't see the "master grub" menu.
Instead you will see the boot menu for the new distro. That's OK, let
it go ahead and boot up. The master grub installation has been
clobbered, but fortunately we keep our feathers numbered for just such
an emergency.

### Un-Borging Your Computer

There are two things that need to be done to correct for the undesired
installation of the distro's copy of grub to the MBR and Bios Boot
partition.

**NOTE:** Since this distro didn't support installing grub to the root
partition, it will reinstall it to the MBR and Bios partition if the
distro ever upgrades or reinstalls grub. You'll need to "un-Borg" your
computer after any upgrade or reinstall of grub by the normal distro
package management tools.



#### Manually Installing Grub to the Root Partition

First, you need to install the distro's copy of grub into the root
partition where we really wanted it to be in the first place. The
grubinstall.sh script that was copied to sda2 can be used to do that:

Mount sda2 if it isn't already mounted:

~~~
# mkdir /mnt/mygrub
# mount /dev/sda2 /mnt/mygrub

~~~

Run the grubinstall.sh script (as root):

~~~
# cd /mnt/mygrub
# ./grubinstall.sh
found grub core at /boot/grub2/i386-pc/core.img
found install at /usr/sbin/grub2-install
root on /dev/sda9
proceed? (y/[n]): 
~~~

Verify that the correct root partition has been chosen, then hit
[Enter].

Grub will be installed, and the core.img file will be locked.

[On some distros you'll see 'grub' instead of 'grub2' in the paths and
filenames above.]

If, in the future, the distro tries to upgrade or reinstall grub and
it fails, you may need to unlock the core.img file and re-try the
upgrade:

~~~
# cd /boot/grub2/i386-pc
# chattr -i core.img
~~~

I find that I almost never do any significant upgrades with
distributions on this machine, I usually just download and install a
new one. So I've never bothered to try to provide any automation
script for unlocking core.img when the distro package manager wants to
upgrade grub.

#### Restoring the Master Grub Installation

Next we need to restore the master grub installation that was
clobbered by the distro's installer (or later by its package
management system). This is done by running the restore.sh script.

Run the script as root, from the directory on sda2 where we put it
during initial setup and did the backups:

~~~
# cd /mnt/mygrub/
# ./restore.sh 
+ dd if=mbr.img of=/dev/sda bs=512
1+0 records in
1+0 records out
512 bytes copied, 0.0197032 s, 26.0 kB/s
+ dd if=bios-boot.img of=/dev/sda1 bs=64K
32+0 records in
32+0 records out
2097152 bytes (2.1 MB, 2.0 MiB) copied, 0.0316006 s, 66.4 MB/s
~~~

### Installed System Tweaks

There are a few more things that you can do to make life easier and
the whole system more robust.

#### Grub Defaults

There are a changes that are recommended in grub settings. Usually,
you do this by editing /etc/default/grub. Some distros might want user
changes put in different file (usually in a subdirectory of
/etc/default/grub.d).

Here are the settings I recommend:

~~~
GRUB_DISABLE_OS_PROBER=true
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
~~~

That will remove all of the extraneous menu entries, force the menu to
be shown, and give you time enough to read it.  One more thing you
might also want to consider would be changing the resolution used by
grub. Many distros default to a tiny font which is difficult to read
on high-DPI monitors. Something like this might help make the menus
legible.

~~~
GRUB_GFXMODE=640x480
~~~

After you've changed the grub config, do whatever is required by the
distro to re-generate the distro's grub.cfg file:

Ubuntu: `udpate-grub`  
RedHat: `grub2-mkconfig -o /boot/grub2/grub.cfg`

The RedHat recipe will probably work for almost any distribution, but
check to see if the directory is grub or grub2.


#### Swap Line in fstab

Most distro installers will create an fstab entry for the swap
partition that identifies the partition by its UUID. That UUID will
change any time a distro installer reformats it. When that happens all
existing fstab entries with the old UUID will break. Usually, the
kernel will still find and use the swap partition, but there are some
pointless startup steps in some distros that will hang looking for a
swap partition with that UUID that no longer exists. For reasons
unfathomable by mere mortals, the Ubuntu startup will wait 2 minutes
for that UUID to appear before it gives up and continues the boot.

To avoid breakage like that, change the swap entry in /etc/fstab to
use the device name (which will never change) instead of the UUID
(which might):

**`/etc/fstab`**

was:
~~~
UUID=5347f427-b046-4e42-89ee-359d18f569fa /       ext4    defaults      1 1
UUID=fc01a4d7-a9b9-4d45-9be8-977357c022c2 none    swap    defaults      0 0
~~~

now:
~~~
UUID=5347f427-b046-4e42-89ee-359d18f569fa /       ext4    defaults      1 1
/dev/sda3                                 none    swap    defaults      0 0
~~~

If your fstab file doesn't have a entry for the swap partition, go
ahead and add one using the device name.

## Done

You can edit the grub.cfg file that's on sda2 to add the new distro
name to the appropriate menu entry [or replace the post-it note,
update the whiteboard, or fix up whatever mechanism you use to
remember what distro is on what partition].

That's it.

When you boot, you should see your master grub menu. Choose the
partition you want and then you should see that distro's grub menu.

## Changing Default Boot Selection

If you find that you need to repeatedly boot into the same partition,
you can change the default selection in the master grub.cfg file by
using the bootto.sh script.  With no arguments, it will show you the
available choices:

~~~
# cd /mnt/mygrub/
# ./bootto.sh 
sda4   Ubuntu Server 22.04.4 
sda5   Ubuntu Server 20.04.6 
sda6  
sda7  
sda8   Centos 7.9 minimal 
sda9   Rocky 8.9 minimal 
sda10  Rocky 9.3 minimal 
sda11  Mint 21.3 Mate 
sda12  OpenSuse Leap 15.5 
 
m.2 drive 
~~~

If passed an argument string, it will search (ignoring case) the
choices. If more than one choice matches, you'll get an error
messages:

~~~
# ./bootto.sh rocky
ambiguous title pattern 'rocky':
sda9   Rocky 8.9 minimal 
sda10  Rocky 9.3 minimal 
~~~

If exactly one choice matches, that choice will be set as the default
and the machine will be rebooted:


~~~
# ./bootto.sh 'rocky 8'
Setting default to 5...
Rebooting...
~~~
