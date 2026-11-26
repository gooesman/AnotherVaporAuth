"""Fail packaging if a CN fork APK is debug/JIT or contains monetization code.

R8's mapping, not obfuscated dex package names, identifies original classes.
The manifest is produced from the actual APK by Android's apkanalyzer.
"""
import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile


def verify(apk: Path, manifest: Path, mapping: Path) -> None:
    android = '{http://schemas.android.com/apk/res/android}'
    root = ET.parse(manifest).getroot()
    app = root.find('application')
    if root.get('package') != 'pro.dotslash.ava.fork' or app is None:
        raise ValueError('Expected the existing AVA Fork application identity')
    if any(app.get(android + field, 'false') != 'false'
           for field in ('debuggable', 'testOnly')):
        raise ValueError('Distributed APK must not be debuggable or test-only')
    with zipfile.ZipFile(apk) as bundle:
        names = set(bundle.namelist())
        required = {'lib/arm64-v8a/libapp.so', 'lib/arm64-v8a/libflutter.so',
                    'lib/arm64-v8a/libava_steam_core.so'}
        if not required <= names or any(bundle.getinfo(n).file_size == 0 for n in required):
            raise ValueError('Expected ARM64 AOT application and native components')
        if any(n.endswith('/kernel_blob.bin') for n in names):
            raise ValueError('A debug/JIT kernel must not be distributed')
        if any(n.startswith('lib/') and not n.startswith('lib/arm64-v8a/') for n in names):
            raise ValueError('Expected an ARM64-only package')
    original = re.findall(r'^(\S+) -> \S+:$', mapping.read_text(encoding='utf-8'), re.M)
    if not original:
        raise ValueError('R8 original-class mapping is missing or empty')
    forbidden = ('com.google.android.gms.ads.', 'com.android.billingclient.',
                 'com.google.android.ump.')
    if any(name.startswith(forbidden) for name in original):
        raise ValueError('Unexpected advertising or billing classes in CN package')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ('apk', 'manifest', 'mapping'):
        parser.add_argument('--' + field, required=True, type=Path)
    args = parser.parse_args()
    verify(args.apk, args.manifest, args.mapping)
    print('Verified: non-debuggable ARM64 AOT fork; R8 mapping excludes ads and billing')
