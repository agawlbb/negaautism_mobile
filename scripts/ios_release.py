"""Ephemeral iOS configuration. Never log configuration or signing contents."""
import base64
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TEMP = Path(os.environ.get('RUNNER_TEMP', '/tmp/nega-ios'))
KEYCHAIN = TEMP / 'nega-ios.keychain-db'
KEY_DIR = Path.home() / '.appstoreconnect/private_keys'
FIREBASE = ROOT / 'ios/Runner/GoogleService-Info.plist'
RELEASE_KEYS = ('IOS_DISTRIBUTION_P12_BASE64', 'IOS_DISTRIBUTION_P12_PASSWORD',
                'IOS_PROFILE_BASE64', 'ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_PRIVATE_KEY_BASE64')

def run(*args):
    try:
        return subprocess.check_output(args, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        raise SystemExit('Apple signing command failed; check certificate/profile configuration') from None

def decode(name):
    return base64.b64decode(os.environ[name], validate=True)

def preflight():
    required = ('FIREBASE_IOS_PLIST_BASE64',)
    if os.environ.get('PUBLISH') == 'true':
        required += RELEASE_KEYS
    missing = [key for key in required if not os.environ.get(key)]
    if missing:
        raise SystemExit('Missing GitHub Actions secrets: ' + ', '.join(missing))

def configure():
    preflight()
    firebase = decode('FIREBASE_IOS_PLIST_BASE64')
    config = plistlib.loads(firebase)
    bundle = config['BUNDLE_ID']
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle):
        raise SystemExit('Invalid Firebase bundle ID')
    if not all(config.get(key) for key in ('GOOGLE_APP_ID', 'API_KEY', 'PROJECT_ID')):
        raise SystemExit('Firebase iOS configuration is incomplete')
    FIREBASE.write_bytes(firebase)
    project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    text = project.read_text().replace('com.coffeybean.negaausismmobile.negaautismMobile', bundle)
    if os.environ.get('PUBLISH') == 'true':
        profile_file = TEMP / 'distribution.mobileprovision'
        profile_file.write_bytes(decode('IOS_PROFILE_BASE64'))
        profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(profile_file)))
        team = profile['TeamIdentifier'][0]
        entitlements = profile['Entitlements']
        if entitlements['application-identifier'] != team + '.' + bundle:
            raise SystemExit('Provisioning profile does not match Firebase bundle ID')
        if profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices'):
            raise SystemExit('An App Store distribution profile is required')
        if entitlements.get('aps-environment') != 'production':
            raise SystemExit('Enable Push Notifications on the App ID and regenerate the profile')
        profiles = Path.home() / 'Library/MobileDevice/Provisioning Profiles'
        profiles.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(profile_file, profiles / (profile['UUID'] + '.mobileprovision'))
        certificate = TEMP / 'distribution.p12'
        certificate.write_bytes(decode('IOS_DISTRIBUTION_P12_BASE64'))
        password = secrets.token_urlsafe(32)
        run('security', 'create-keychain', '-p', password, str(KEYCHAIN))
        run('security', 'set-keychain-settings', '-lut', '21600', str(KEYCHAIN))
        run('security', 'unlock-keychain', '-p', password, str(KEYCHAIN))
        run('security', 'import', str(certificate), '-P', os.environ['IOS_DISTRIBUTION_P12_PASSWORD'],
            '-A', '-t', 'cert', '-f', 'pkcs12', '-k', str(KEYCHAIN))
        run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', password, str(KEYCHAIN))
        run('security', 'list-keychains', '-d', 'user', '-s', str(KEYCHAIN))
        settings = ('CODE_SIGN_STYLE = Manual;\n'
                    f'DEVELOPMENT_TEAM = {team};\n'
                    'CODE_SIGN_IDENTITY = "Apple Distribution";\n'
                    f'PROVISIONING_PROFILE_SPECIFIER = "{profile["UUID"]}";')
        text = text.replace('INFOPLIST_FILE = Runner/Info.plist;',
                            'INFOPLIST_FILE = Runner/Info.plist;\n' + settings)
        (TEMP / 'ExportOptions.plist').write_bytes(plistlib.dumps({
            'method': 'app-store-connect', 'teamID': team, 'signingStyle': 'manual',
            'provisioningProfiles': {bundle: profile['UUID']}, 'uploadSymbols': True,
            'manageAppVersionAndBuildNumber': False,
        }))
        KEY_DIR.mkdir(parents=True, exist_ok=True)
        key = KEY_DIR / ('AuthKey_' + os.environ['ASC_KEY_ID'] + '.p8')
        key.write_bytes(decode('ASC_PRIVATE_KEY_BASE64'))
        key.chmod(0o600)
    project.write_text(text)

def cleanup():
    if KEYCHAIN.exists():
        run('security', 'delete-keychain', str(KEYCHAIN))
    FIREBASE.unlink(missing_ok=True)
    for name in ('distribution.p12', 'distribution.mobileprovision', 'ExportOptions.plist'):
        (TEMP / name).unlink(missing_ok=True)
    key_id = os.environ.get('ASC_KEY_ID')
    if key_id:
        (KEY_DIR / ('AuthKey_' + key_id + '.p8')).unlink(missing_ok=True)

if __name__ == '__main__':
    {'preflight': preflight, 'configure': configure, 'cleanup': cleanup}[sys.argv[1]]()
