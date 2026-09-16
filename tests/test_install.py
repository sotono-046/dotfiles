"""Exercise installer changes against disposable homes; never source shell config."""

import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SKILLS = REPO / 'agent' / 'skills'
RUNTIMES = ('.claude', '.codex', '.gemini')


def snapshot(root):
    """Capture contents without following symlinks into the real home or repo."""
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(directory) / name
            relative = str(path.relative_to(root))
            if path.is_symlink():
                result[relative] = ('link', os.readlink(path))
            elif path.is_file():
                result[relative] = ('file', hashlib.sha256(path.read_bytes()).hexdigest())
            else:
                result[relative] = ('directory',)
    return result


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-install-test-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()
        self.backups = self.home / '.local/state/dotfiles/backups'

    def run_install(self, *args, target=None, success=True):
        env = os.environ.copy()
        env['DOTFILES_TARGET_HOME'] = str(self.home if target is None else target)
        result = subprocess.run(
            ['bash', str(REPO / 'install.sh'), *args],
            cwd=REPO, env=env, text=True, capture_output=True, timeout=30,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def write_skill(self, relative, content):
        path = self.home / relative / 'SKILL.md'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def test_all_runtimes_repeat_preserves_user_skills_and_live_system(self):
        cloudflare = self.write_skill('.gemini/skills/cloudflare', 'user cloudflare')
        user = self.write_skill('.claude/skills/personal-only', 'user claude')
        system = self.home / '.codex/skills/.system/local-sentinel'
        system.parent.mkdir(parents=True)
        system.write_text('Codex owns this directory')
        self.run_install('--agent-only')
        for runtime in RUNTIMES:
            for skill in SKILLS.iterdir():
                if (skill / 'SKILL.md').is_file() and '.dotbackup.' not in skill.name:
                    installed = self.home / runtime / 'skills' / skill.name
                    self.assertTrue(installed.is_symlink(), installed)
                    self.assertEqual(installed.resolve(), skill.resolve())
        self.assertEqual(cloudflare.read_text(), 'user cloudflare')
        self.assertEqual(user.read_text(), 'user claude')
        self.assertEqual(system.read_text(), 'Codex owns this directory')
        self.assertEqual(list(system.parent.iterdir()), [system])
        self.assertFalse((self.home / '.zshrc').exists())
        before = snapshot(self.home)
        self.run_install('--agent-only')
        self.assertEqual(before, snapshot(self.home))

    def test_replaced_and_legacy_backups_are_retained_outside_discovery(self):
        self.write_skill('.codex/skills/git-ops', 'replaced skill')
        old = self.write_skill('.codex/skills/git-ops.dotbackup.20260827081549', 'older skill')
        ordinary = self.home / '.codex/skills/notes.dotbackup.20260827'
        ordinary.mkdir(parents=True)
        (ordinary / 'notes.txt').write_text('not a skill')
        nested = self.write_skill('.gemini/skills/cloudflare/nested.dotbackup.20260827', 'nested user data')
        elsewhere = self.write_skill('other-tree/old.dotbackup.20260827', 'outside skills roots')
        self.run_install('--agent-only')
        self.assertFalse(old.exists())
        self.assertTrue((self.home / '.codex/skills/git-ops').is_symlink())
        copies = {p.read_text() for p in self.backups.rglob('SKILL.md')}
        self.assertEqual(copies, {'replaced skill', 'older skill'})
        self.assertEqual((ordinary / 'notes.txt').read_text(), 'not a skill')
        self.assertEqual(nested.read_text(), 'nested user data')
        self.assertEqual(elsewhere.read_text(), 'outside skills roots')
        before = snapshot(self.home)
        self.run_install('--agent-only')
        self.assertEqual(before, snapshot(self.home))

    def test_successive_replacements_never_overwrite_backup_contents(self):
        self.write_skill('.claude/skills/git-ops', 'first copy')
        self.run_install('--agent-only')
        (self.home / '.claude/skills/git-ops').unlink()
        self.write_skill('.claude/skills/git-ops', 'second copy')
        self.run_install('--agent-only')
        copies = [p.read_text() for p in self.backups.rglob('SKILL.md')]
        self.assertCountEqual(copies, ['first copy', 'second copy'])

    def test_dry_run_leaves_existing_and_new_homes_unchanged(self):
        self.write_skill('.codex/skills/git-ops', 'replace later')
        self.write_skill('.codex/skills/git-ops.dotbackup.20260827', 'move later')
        before = snapshot(self.home)
        result = self.run_install('--agent-only', '--dry-run')
        self.assertIn('.local/state/dotfiles/backups/', result.stdout)
        self.assertEqual(before, snapshot(self.home))
        fresh = Path(self.temp.name) / 'not-created'
        self.run_install('--links-only', '--dry-run', target=fresh)
        self.assertFalse(fresh.exists())

    def test_whole_directory_link_migration_does_not_change_source(self):
        for runtime in ('.claude', '.codex'):
            target = self.home / runtime / 'skills'
            target.parent.mkdir()
            target.symlink_to(SKILLS, target_is_directory=True)
        before = snapshot(SKILLS)
        self.run_install('--agent-only', '--dry-run')
        self.assertTrue((self.home / '.codex/skills').is_symlink())
        self.run_install('--agent-only')
        self.assertFalse((self.home / '.codex/skills').is_symlink())
        self.assertEqual(before, snapshot(SKILLS))
        system = self.home / '.codex/skills/.system'
        self.assertFalse(system.is_symlink())
        self.assertEqual(snapshot(system), snapshot(SKILLS / '.system'))
        self.assertFalse((self.home / '.gemini/skills/.system').exists())

    def test_links_only_and_rejected_target_homes(self):
        self.run_install('--links-only')
        self.assertEqual((self.home / '.zshrc').resolve(), REPO / '.zshrc')
        self.assertTrue((self.home / '.gemini/skills/git-ops').is_symlink())
        for target in ('/', '/tmp/../', 'relative-home'):
            self.run_install('--agent-only', '--dry-run', target=target, success=False)
        self.run_install('--agent-only', '--links-only', success=False)


if __name__ == '__main__':
    unittest.main()
