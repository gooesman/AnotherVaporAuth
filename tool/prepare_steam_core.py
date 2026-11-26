#!/usr/bin/env python3
"""Stage a pinned, unchanged Android core and the matching source release files.

No binary is executed. Run from the repository root. Files under src/main are
generated build inputs and ignored by Git; core.json and the notices are tracked.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parent.parent
PINS = json.loads((ROOT / 'third_party/mihomo/core.json').read_text())


def fetch(url, digest, limit):
    request = urllib.request.Request(url, headers={'User-Agent': 'AVA-Core-Packaging/1'})
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read(limit + 1)
    if len(data) > limit or hashlib.sha256(data).hexdigest() != digest:
        raise SystemExit('Pinned core/source integrity check failed')
    return data


def stage_android(archive=None):
    pin = PINS['android']
    data = Path(archive).read_bytes() if archive else fetch(
        pin['url'], pin['archive_sha256'], 32 * 1024 * 1024)
    if hashlib.sha256(data).hexdigest() != pin['archive_sha256']:
        raise SystemExit('Android archive integrity check failed')
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as compressed:
        executable = compressed.read(80 * 1024 * 1024 + 1)
    if len(executable) > 80 * 1024 * 1024 or hashlib.sha256(executable).hexdigest() != pin['executable_sha256']:
        raise SystemExit('Android executable integrity check failed')
    main = ROOT / 'app/android/app/src/main'
    target = main / 'jniLibs/arm64-v8a/libava_steam_core.so'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(executable)
    target.chmod(0o755)
    assets = main / 'assets'
    assets.mkdir(parents=True, exist_ok=True)
    (assets / 'steam_core_sha256.txt').write_text(pin['executable_sha256'] + '\n')
    shutil.copyfile(ROOT / 'third_party/mihomo/LICENSE', assets / 'steam_core_LICENSE.txt')
    shutil.copyfile(ROOT / 'third_party/mihomo/NOTICE', assets / 'steam_core_NOTICE.txt')
    print('Staged verified Android ARM64 component')


def stage_source(output, archive=None):
    data = Path(archive).read_bytes() if archive else fetch(
        PINS['source_url'], PINS['source_sha256'], 32 * 1024 * 1024)
    if hashlib.sha256(data).hexdigest() != PINS['source_sha256']:
        raise SystemExit('Source integrity check failed')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    source = output / f'mihomo-{PINS["version"]}-source.tar.gz'
    source.write_bytes(data)
    files = [source]
    for name in ['LICENSE', 'NOTICE']:
        target = output / f'mihomo-{name}.txt'
        shutil.copyfile(ROOT / f'third_party/mihomo/{name}', target)
        files.append(target)
    metadata = {
        'schema': 1, 'component': 'mihomo', 'version': PINS['version'],
        'source_commit': PINS['commit'],
        'repository': os.environ.get('GITHUB_REPOSITORY', 'local'),
        'commit': os.environ.get('GITHUB_SHA', 'local'),
        'run_id': int(os.environ.get('GITHUB_RUN_ID', '0')),
        'files': {p.name: {'size': p.stat().st_size,
                  'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files},
    }
    (output / 'core-provenance.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('Staged corresponding source snapshot and component notices')


def verify_apk(path):
    with zipfile.ZipFile(path) as apk:
        binary = apk.read('lib/arm64-v8a/libava_steam_core.so')
        if hashlib.sha256(binary).hexdigest() != PINS['android']['executable_sha256']:
            raise SystemExit('APK contains a stripped or modified core')
        if apk.read('assets/steam_core_sha256.txt').decode().strip() != PINS['android']['executable_sha256']:
            raise SystemExit('APK core digest asset mismatch')
        if apk.read('assets/steam_core_LICENSE.txt') != (ROOT / 'third_party/mihomo/LICENSE').read_bytes():
            raise SystemExit('APK missing the component license')
    print('Verified unchanged packaged core and license')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--android', action='store_true')
    parser.add_argument('--android-archive')
    parser.add_argument('--source-output')
    parser.add_argument('--source-archive')
    parser.add_argument('--verify-apk')
    args = parser.parse_args()
    if args.android:
        stage_android(args.android_archive)
    if args.source_output:
        stage_source(args.source_output, args.source_archive)
    if args.verify_apk:
        verify_apk(args.verify_apk)
