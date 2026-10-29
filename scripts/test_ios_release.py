"""Synthetic signing tests: no Apple calls, keys, or production configuration."""
import base64
import datetime
import importlib.util
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('ios_release', Path(__file__).with_name('ios_release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

class SigningConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'ios/Runner').mkdir(parents=True)
        (self.root / 'ios/Runner.xcodeproj').mkdir()
        self.project = self.root / 'ios/Runner.xcodeproj/project.pbxproj'
        self.project.write_text('INFOPLIST_FILE = Runner/Info.plist;')
        config = {'BUNDLE_ID': 'org.negaautism.mobile', 'GOOGLE_APP_ID': 'synthetic',
                  'API_KEY': 'synthetic', 'PROJECT_ID': 'synthetic'}
        env = {name: 'synthetic' for name in release.RELEASE_KEYS}
        env.update(PUBLISH='true', ASC_KEY_ID='ABCDEFGHIJ',
                   ASC_ISSUER_ID='00000000-0000-4000-8000-000000000000',
                   FIREBASE_IOS_PLIST_BASE64=base64.b64encode(plistlib.dumps(config)).decode(),
                   IOS_PROFILE_BASE64=base64.b64encode(b'profile').decode(),
                   IOS_DISTRIBUTION_P12_BASE64=base64.b64encode(b'certificate').decode(),
                   ASC_PRIVATE_KEY_BASE64=base64.b64encode(b'private-key').decode())
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, env, clear=True).start()
        for name, value in {'ROOT': self.root, 'TEMP': self.root,
                            'KEYCHAIN': self.root / 'signing.keychain-db',
                            'KEY_DIR': self.root / 'api-keys',
                            'FIREBASE': self.root / 'ios/Runner/GoogleService-Info.plist'}.items():
            patch.object(release, name, value).start()
        patch.object(Path, 'home', return_value=self.root).start()
        self.profile = {'TeamIdentifier': ['FKR675M7PM'],
                        'UUID': '00000000-0000-4000-8000-000000000001',
                        'ExpirationDate': datetime.datetime(2099, 1, 1),
                        'Entitlements': {'application-identifier': 'FKR675M7PM.org.negaautism.mobile',
                                         'aps-environment': 'production', 'get-task-allow': False}}
        self.commands = patch.object(release, 'run', side_effect=self.security).start()

    def security(self, *args):
        return plistlib.dumps(self.profile) if args[:2] == ('security', 'cms') else b''

    def test_configures_matching_distribution_profile_and_cleans_secrets(self):
        release.configure()
        options = plistlib.loads((self.root / 'ExportOptions.plist').read_bytes())
        self.assertEqual(options['provisioningProfiles']['org.negaautism.mobile'], self.profile['UUID'])
        self.assertEqual(options['method'], 'app-store-connect')
        self.assertIn('DEVELOPMENT_TEAM = FKR675M7PM;\n', self.project.read_text())
        self.assertEqual(plistlib.loads((self.root / 'ios/Runner/Runner.entitlements').read_bytes()),
                         {'aps-environment': 'production'})
        release.cleanup()
        self.assertFalse(release.FIREBASE.exists())
        self.assertFalse((release.KEY_DIR / 'AuthKey_ABCDEFGHIJ.p8').exists())
        self.assertFalse((self.root / 'distribution.p12').exists())

    def test_rejects_wrong_app(self):
        self.profile['Entitlements']['application-identifier'] = 'FKR675M7PM.org.example.other'
        with self.assertRaisesRegex(SystemExit, 'does not match'):
            release.configure()
        self.assertFalse((self.root / 'distribution.p12').exists())

    def test_rejects_expired_profile(self):
        self.profile['ExpirationDate'] = datetime.datetime(2000, 1, 1)
        with self.assertRaisesRegex(SystemExit, 'expired'):
            release.configure()

    def test_rejects_development_and_adhoc_profiles(self):
        self.profile['ProvisionedDevices'] = ['synthetic-device']
        with self.assertRaisesRegex(SystemExit, 'App Store distribution'):
            release.configure()

    def test_rejects_missing_production_push_entitlement(self):
        self.profile['Entitlements']['aps-environment'] = 'development'
        with self.assertRaisesRegex(SystemExit, 'Push Notifications'):
            release.configure()

    def test_rejects_key_id_path_traversal(self):
        os.environ['ASC_KEY_ID'] = '../unsafe'
        with self.assertRaisesRegex(SystemExit, 'key ID'):
            release.preflight()

if __name__ == '__main__':
    unittest.main()