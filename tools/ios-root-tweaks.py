#!/usr/bin/env python3
"""Bring-up tweaks for an iOS root made by tools/mkios-root.sh (idempotent).

  ios-root-tweaks.py MOUNTED_ROOT

MOUNTED_ROOT is the HFS+ image mounted read-write as root. launchd.plist is read from disk
when the kernel boots with launchd_unsecure_cache=1, so it can be edited:
  - every job's _PanicOnCrash key is renamed (_PanicOnCrasX): a crashing daemon must not panic
    the kernel during bring-up.
  - /private/var/containers/{Bundle,Data/System,Shared/SystemGroup,Temp}: on a device these live
    on the data volume, which this image does not have.
"""
import os, plistlib, sys


def launchd(root):
    path = os.path.join(root, 'System/Library/xpc/launchd.plist')
    st = os.stat(path)
    with open(path, 'rb') as f:
        plist = plistlib.load(f)
    n = 0
    for job in plist.get('LaunchDaemons', {}).values():
        if '_PanicOnCrash' in job:
            job['_PanicOnCrasX'] = job.pop('_PanicOnCrash')
            n += 1
    with open(path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    os.chown(path, st.st_uid, st.st_gid)
    os.chmod(path, st.st_mode & 0o7777)
    print('launchd.plist: renamed _PanicOnCrash in', n, 'jobs')


def containers(root):
    for d in ('Bundle', 'Data/System', 'Shared/SystemGroup', 'Temp'):
        p = os.path.join(root, 'private/var/containers', d)
        os.makedirs(p, exist_ok=True)
        os.chmod(p, 0o755)
    print('containers: ok')


if __name__ == '__main__':
    launchd(sys.argv[1])
    containers(sys.argv[1])
