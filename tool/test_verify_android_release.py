import tempfile
import unittest
from pathlib import Path
import zipfile

from verify_android_release import verify


class ReleaseGateTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.apk = self.root / 'app.apk'
        self.manifest = self.root / 'manifest.xml'
        self.mapping = self.root / 'mapping.txt'
        self.write_manifest()
        self.mapping.write_text('pro.dotslash.ava.MainActivity -> a.b:\n')
        self.write_apk()

    def write_manifest(self, attributes='', package='pro.dotslash.ava.fork'):
        self.manifest.write_text(
            f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
            f'package="{package}"><application {attributes}/></manifest>')

    def write_apk(self, extra=None, aot=True):
        with zipfile.ZipFile(self.apk, 'w') as bundle:
            for name in ('libflutter.so', 'libava_steam_core.so') + (('libapp.so',) if aot else ()):
                bundle.writestr('lib/arm64-v8a/' + name, b'fixture')
            if extra:
                bundle.writestr(extra, b'fixture')

    def check(self):
        verify(self.apk, self.manifest, self.mapping)

    def test_accepts_release_with_original_package(self):
        self.check()

    def test_rejects_debug_or_test_only(self):
        for field in ('debuggable', 'testOnly'):
            with self.subTest(field=field):
                self.write_manifest(f'android:{field}="true"')
                with self.assertRaises(ValueError):
                    self.check()

    def test_rejects_different_install_identity(self):
        self.write_manifest(package='pro.dotslash.ava.dev')
        with self.assertRaises(ValueError):
            self.check()

    def test_rejects_jit_and_missing_aot(self):
        for extra, aot in [('assets/flutter_assets/kernel_blob.bin', True), (None, False)]:
            with self.subTest(extra=extra, aot=aot):
                self.write_apk(extra, aot)
                with self.assertRaises(ValueError):
                    self.check()

    def test_rejects_obfuscated_ad_or_billing_classes(self):
        for package in ('com.google.android.gms.ads.AdView', 'com.google.android.ump.ConsentForm',
                        'com.android.billingclient.api.BillingClient'):
            with self.subTest(package=package):
                self.mapping.write_text(f'{package} -> x.y:\n')
                with self.assertRaises(ValueError):
                    self.check()

    def test_rejects_missing_original_names(self):
        self.mapping.write_text('# No class mapping\n')
        with self.assertRaises(ValueError):
            self.check()

    def test_rejects_additional_abis(self):
        self.write_apk('lib/x86_64/libapp.so')
        with self.assertRaises(ValueError):
            self.check()


if __name__ == '__main__':
    unittest.main()
