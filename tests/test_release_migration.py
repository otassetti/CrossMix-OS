"""Exercise the real migration functions on temporary save trees."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / 'System/usr/trimui/scripts/crossmix_update.sh').read_text()
FUNCTIONS = SCRIPT[SCRIPT.index('migrate_ra_copy() {'):SCRIPT.index('move_without_replace() {')]


class MigrationTests(unittest.TestCase):
    def test_flatten_preserves_conflicts_hidden_files_and_existing_layout(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            roms, backup, dest = root / 'Roms', root / 'backup', root / 'dest'
            for system in ('GB', 'GBC', 'GBA'):
                (roms / system).mkdir(parents=True)
            source = backup / 'saves'
            files = {
                'GB/Gambatte/Same game.srm': b'GB progress',
                'GBC/Gambatte/Same game.srm': b'GBC progress',
                'GBA/Gambatte/Same game.srm': b'third progress',
                'GB/Gambatte/.hidden.srm': b'hidden',
                'GB/Gambatte/sub folder/Other.srm': b'other',
                'GB/Gambatte/Equal.srm': b'equal',
                'GBC/Gambatte/Equal.srm': b'equal',
                'mGBA/Existing.srm': b'new layout',
                'Root.srm': b'root',
            }
            for relative, content in files.items():
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            functions = FUNCTIONS.replace('/mnt/SDCARD/Roms', str(roms))
            subprocess.run(['bash', '-c', functions + '\nBCK_DIR="$1"\nmigrate_ra_flat "RetroArch saves" "$2" "$3"',
                            'test', str(backup), str(source), str(dest)], check=True)
            self.assertEqual((dest / 'Gambatte/Same game.srm').read_bytes(), b'GB progress')
            conflicts = backup / 'Migration_Conflicts/RetroArch saves'
            self.assertEqual((conflicts / 'GBC/Gambatte/Same game.srm').read_bytes(), b'GBC progress')
            self.assertEqual((conflicts / 'GBA/Gambatte/Same game.srm').read_bytes(), b'third progress')
            self.assertFalse((conflicts / 'GBC/Gambatte/Equal.srm').exists())
            self.assertEqual((dest / 'Gambatte/.hidden.srm').read_bytes(), b'hidden')
            self.assertEqual((dest / 'Gambatte/sub folder/Other.srm').read_bytes(), b'other')
            self.assertEqual((dest / 'mGBA/Existing.srm').read_bytes(), b'new layout')
            self.assertEqual((dest / 'Root.srm').read_bytes(), b'root')
            for relative, content in files.items():
                self.assertEqual((source / relative).read_bytes(), content)

    def test_extraction_failure_stops_before_restore(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            start = SCRIPT.index('if /tmp/7zz x -aoa')
            end = SCRIPT.index('echo "${BLUE}=====================  Restoring saves', start)
            block = SCRIPT[start:end].replace('/tmp/7zz', 'false').replace('/tmp/stay_awake', str(root / 'awake'))
            result = subprocess.run(['bash', '-c', block + '\ntouch "$1/restore-ran"', 'test', str(root)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 5)
            self.assertFalse((root / 'restore-ran').exists())
            self.assertIn('Installation stopped', result.stdout)

    def test_corrupt_archive_stops_before_installed_files_move(self):
        start = SCRIPT.index('if ! /tmp/7zz t')
        end = SCRIPT.index('echo "${BLUE}==============          Creating backup', start)
        block = SCRIPT[start:end].replace('/tmp/7zz', 'false').replace('/tmp/stay_awake', '/dev/null/nonexistent')
        result = subprocess.run(['bash', '-c', block], capture_output=True, text=True)
        self.assertEqual(result.returncode, 4)
        self.assertIn('Installed files have not been moved', result.stdout)


if __name__ == '__main__':
    unittest.main()
