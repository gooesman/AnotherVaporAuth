"""Exercise release-promotion guards without executing the workflow or GitHub CLI."""

import ast
import copy
import hashlib
from pathlib import Path
import re
import shutil
import tempfile
import textwrap
import unittest
from unittest.mock import patch


def load_release_guards():
    workflow = Path(__file__).resolve().parents[1] / '.github/workflows/fork-release.yml'
    text = workflow.read_text(encoding='utf-8')
    prefix, script = text.split("python3 - <<'PY'\n", 1)
    script = textwrap.dedent(script).rsplit('\nPY', 1)[0]
    tree = ast.parse(script, filename=str(workflow))
    ast.increment_lineno(tree, prefix.count('\n') + 1)
    names = {'require', 'select_release_draft', 'verify_release_draft',
             'add_windows_compatibility_alias'}
    functions = [node for node in tree.body
                 if isinstance(node, ast.FunctionDef) and node.name in names]
    if {node.name for node in functions} != names:
        raise AssertionError('Release guard functions are missing from the workflow')
    # Only the named function definitions enter this module. In particular, no
    # workflow top-level API calls, environment reads or publication can run.
    module = ast.Module(body=functions, type_ignores=[])
    namespace = {'hashlib': hashlib, 're': re, 'Path': Path, 'shutil': shutil}
    exec(compile(module, str(workflow), 'exec'), namespace)
    return (namespace['select_release_draft'], namespace['verify_release_draft'],
            namespace['add_windows_compatibility_alias'])


class ReleaseDraftGateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        select, verify, _ = load_release_guards()
        cls.select = staticmethod(select)
        cls.verify = staticmethod(verify)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.tag = 'v1.5.1+100014'
        self.commit = '1' * 40
        self.notes = 'Verified Windows and Android build.\n已验证电脑和手机安装包。\n'
        self.paths = []
        asset_records = []
        for index, name in enumerate([
            'GooeSteamKit-v1.5.1+100014-windows-x64-setup.exe',
            'AVA-pc-v1.5.1+100014-windows-x64-setup.exe',
            'AVA-Fork-v1.5.1+100014-android-arm64.apk',
            'mihomo-v1.19.32-source.tar.gz',
            'mihomo-LICENSE.txt',
            'mihomo-NOTICE.txt',
            'release-provenance.json',
            'SHA256SUMS.txt',
        ]):
            path = self.root / name
            content = f'synthetic release asset {index}'.encode()
            path.write_bytes(content)
            self.paths.append(path)
            asset_records.append({
                'id': index + 1,
                'name': name,
                'state': 'uploaded',
                'size': len(content),
                'digest': 'sha256:' + hashlib.sha256(content).hexdigest(),
            })
        self.draft = {
            'id': 409512964,
            'tag_name': self.tag,
            'target_commitish': self.commit,
            'draft': True,
            'prerelease': False,
            'body': self.notes,
            'assets': asset_records,
        }

    def select_draft(self, releases, resume_id=None):
        return self.select(releases, self.tag, self.commit, resume_id)

    def verify_draft(self, draft=None):
        return self.verify(
            self.draft if draft is None else draft,
            self.tag, self.commit, self.paths, self.notes,
        )

    def test_fresh_release_does_not_select_a_draft(self):
        self.assertIsNone(self.select_draft([]))

    def test_unrelated_release_does_not_block_a_fresh_tag(self):
        unrelated = {**self.draft, 'tag_name': 'v1.5.1+100013', 'draft': False}
        self.assertIsNone(self.select_draft([unrelated]))

    def test_existing_draft_requires_explicit_resume(self):
        with self.assertRaises(SystemExit):
            self.select_draft([self.draft])

    def test_explicit_matching_draft_is_selected(self):
        self.assertEqual(
            self.select_draft([self.draft], self.draft['id']),
            self.draft['id'],
        )

    def test_resume_does_not_create_a_missing_draft(self):
        with self.assertRaises(SystemExit):
            self.select_draft([], self.draft['id'])

    def test_resume_rejects_wrong_id_tag_and_commit(self):
        changes = [
            {'id': self.draft['id'] + 1},
            {'tag_name': 'v1.5.1+100013'},
            {'target_commitish': '2' * 40},
            {'target_commitish': 'main'},
        ]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(SystemExit):
                self.select_draft(
                    [{**self.draft, **change}], self.draft['id'],
                )

    def test_resume_rejects_public_and_prerelease_records(self):
        for change in [{'draft': False}, {'prerelease': True}]:
            with self.subTest(change=change), self.assertRaises(SystemExit):
                self.select_draft(
                    [{**self.draft, **change}], self.draft['id'],
                )

    def test_select_rejects_ambiguous_matching_drafts(self):
        other = {**self.draft, 'id': self.draft['id'] + 1}
        with self.assertRaises(SystemExit):
            self.select_draft([self.draft, other], self.draft['id'])

    def test_fully_verified_draft_can_be_published(self):
        self.verify_draft()

    def test_verification_rejects_changed_release_identity(self):
        for change in [
            {'tag_name': 'v1.5.1+100013'},
            {'target_commitish': '2' * 40},
            {'target_commitish': 'main'},
            {'draft': False},
            {'prerelease': True},
        ]:
            with self.subTest(change=change), self.assertRaises(SystemExit):
                self.verify_draft({**self.draft, **change})

    def test_verification_rejects_different_or_missing_notes(self):
        for notes in ['Different notes', '', None]:
            with self.subTest(notes=notes), self.assertRaises(SystemExit):
                self.verify_draft({**self.draft, 'body': notes})

    def test_verification_rejects_missing_extra_and_duplicate_assets(self):
        assets = self.draft['assets']
        cases = [
            assets[:-1],
            assets + [{**assets[0], 'id': 99, 'name': 'unexpected.exe'}],
            assets + [{**assets[0], 'id': 99}],
            assets[:-1] + [copy.deepcopy(assets[0])],
        ]
        for index, records in enumerate(cases):
            with self.subTest(case=index), self.assertRaises(SystemExit):
                self.verify_draft({**self.draft, 'assets': records})

    def test_verification_rejects_unfinished_asset_uploads(self):
        for state in ['new', 'starter', 'failed', None]:
            draft = copy.deepcopy(self.draft)
            draft['assets'][0]['state'] = state
            with self.subTest(state=state), self.assertRaises(SystemExit):
                self.verify_draft(draft)

    def test_verification_rejects_wrong_sizes(self):
        for size in [0, self.draft['assets'][0]['size'] + 1, '25', None]:
            draft = copy.deepcopy(self.draft)
            draft['assets'][0]['size'] = size
            with self.subTest(size=size), self.assertRaises(SystemExit):
                self.verify_draft(draft)

    def test_verification_rejects_absent_or_mismatched_digests(self):
        for digest in [None, '', 'sha256:' + '0' * 64, 'md5:' + '0' * 32]:
            draft = copy.deepcopy(self.draft)
            draft['assets'][0]['digest'] = digest
            with self.subTest(digest=digest), self.assertRaises(SystemExit):
                self.verify_draft(draft)

    def test_verification_checks_local_bytes_again_before_publication(self):
        path = self.paths[0]
        path.write_bytes(b'x' * path.stat().st_size)
        with self.assertRaises(SystemExit):
            self.verify_draft()


class WindowsCompatibilityAssetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _, _, alias = load_release_guards()
        cls.add_alias = staticmethod(alias)

    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.tag = 'v1.5.17+100042'
        self.package = Path(directory.name) / f'GooeSteamKit-{self.tag}-windows-x64-setup.exe'
        self.package.write_bytes(b'synthetic verified Windows setup')
        self.metadata = {
            'release_file': self.package.name,
            'file': self.package.name,
            'sha256': hashlib.sha256(self.package.read_bytes()).hexdigest(),
            'size': self.package.stat().st_size,
            'artifact_id': 42,
            'artifact_sha256': 'a' * 64,
            'commit': 'b' * 40,
        }

    def test_alias_keeps_bytes_and_source_provenance(self):
        alias, metadata = self.add_alias(self.package, self.metadata, self.tag)
        self.assertEqual(alias.name, f'AVA-pc-{self.tag}-windows-x64-setup.exe')
        self.assertEqual(alias.read_bytes(), self.package.read_bytes())
        self.assertEqual(metadata, {
            **self.metadata, 'release_file': alias.name,
            'compatibility_alias_for': self.package.name,
        })
        # Both records can go through the existing checksum/publication gates.
        for path, record in [(self.package, self.metadata), (alias, metadata)]:
            self.assertEqual(path.name, record['release_file'])
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record['sha256'])

    def test_rejects_other_version_and_unbranded_source(self):
        for tag, name in [('v1.5.17+100043', self.package.name),
                          (self.tag, f'AVA-pc-{self.tag}-windows-x64-setup.exe')]:
            with self.subTest(tag=tag, name=name), self.assertRaises(SystemExit):
                self.add_alias(self.package.with_name(name), self.metadata, tag)

    def test_rejects_different_copied_bytes(self):
        def tamper(_source, destination):
            destination.write_bytes(b'x' * self.metadata['size'])
        with patch.object(shutil, 'copyfile', tamper), self.assertRaises(SystemExit):
            self.add_alias(self.package, self.metadata, self.tag)

    def test_rejects_wrong_provenance_size(self):
        with self.assertRaises(SystemExit):
            self.add_alias(self.package, {**self.metadata, 'size': 1}, self.tag)


if __name__ == '__main__':
    unittest.main()
