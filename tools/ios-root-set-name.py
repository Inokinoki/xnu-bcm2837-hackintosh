#!/usr/bin/env python3
"""Run inside the container by ios-root-set-name.sh: edit the mounted iOS root.

  ios-root-set-name.py ROOT NAME
"""
import os, plistlib, re, sys

root, name = sys.argv[1], sys.argv[2]
host = re.sub(r'[^A-Za-z0-9-]+', '-', name).strip('-')

p = os.path.join(root, 'private/var/preferences/SystemConfiguration/preferences.plist')
raw = open(p, 'rb').read()
fmt = plistlib.FMT_BINARY if raw[:6] == b'bplist' else plistlib.FMT_XML
d = plistlib.loads(raw)
d['System']['System']['ComputerName'] = name
d['System']['System']['HostName'] = host
d['System']['Network']['HostNames']['LocalHostName'] = host
open(p, 'wb').write(plistlib.dumps(d, fmt=fmt))
print('preferences.plist: ComputerName', repr(name), 'host', repr(host))

# MobileGestalt rebuilds its cache from the device tree (marketing name and so on) when it is gone
mg = os.path.join(root, 'private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/'
                  'Library/Caches/com.apple.MobileGestalt.plist')
if os.path.exists(mg):
    os.remove(mg)
    print('removed', os.path.relpath(mg, root))
