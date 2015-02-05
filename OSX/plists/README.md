# OSX plists

### LaunchAgent plists
**org.openzfsonosx.ilovezfs.zfs.zpool-import.plist**
: A launchd script to automatically import your ZFS zpool on OS X. This script is adapted, from one of the same title by ilovezfs, to import a zpool from a File VDEV located in /vdev. 

**org.redpanda.noatime.plist**
: Automatically disable atime on the root filesystem whenever a filesystem is mounted. Adapted from a common plist floating around the internet from a defunct blog called Nullvision.

**org.redpanda.macports.selfupdate.plist**
: Run 'macports selfupdate' at a scheduled time. The job fires at 01:15am. This is just a small timesaver so I don't have to remember to do it every time I work with macports.

### LaunchDaemon plists
