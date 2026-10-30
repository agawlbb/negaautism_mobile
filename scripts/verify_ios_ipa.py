"""Verify the exported iOS identity and distribution signature before upload."""
import datetime
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile


def run(*args):
    return subprocess.check_output(args, stderr=subprocess.PIPE)


def verify():
    packages = list(Path('build/ios/ipa').glob('*.ipa'))
    if len(packages) != 1:
        raise SystemExit('Expected exactly one exported IPA')
    with tempfile.TemporaryDirectory() as temp:
        run('ditto', '-x', '-k', str(packages[0]), temp)
        apps = list((Path(temp) / 'Payload').glob('*.app'))
        if len(apps) != 1:
            raise SystemExit('Expected exactly one iOS app')
        app = apps[0]
        run('codesign', '--verify', '--deep', '--strict', str(app))
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')))
        entitlements = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', str(app)))
        expected = 'FKR675M7PM.org.negaautism.mobile'
        scenes = info.get('UIApplicationSceneManifest', {}).get('UISceneConfigurations', {}).get('UIWindowSceneSessionRoleApplication', [])
        checks = {
            'scene lifecycle': any(scene.get('UISceneDelegateClassName') == 'FlutterSceneDelegate'
                                   and scene.get('UISceneStoryboardFile') == 'Main' for scene in scenes),
            'bundle ID': info.get('CFBundleIdentifier') == 'org.negaautism.mobile',
            'build number': info.get('CFBundleVersion') == os.environ['GITHUB_RUN_NUMBER'],
            'team': profile.get('TeamIdentifier') == ['FKR675M7PM'],
            'profile app': profile['Entitlements'].get('application-identifier') == expected,
            'signed app': entitlements.get('application-identifier') == expected,
            'production push': entitlements.get('aps-environment') == 'production',
            'distribution signing': not entitlements.get('get-task-allow', False),
            'App Store profile': not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'),
            'unexpired profile': profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),
        }
        firebase = plistlib.loads((app / 'GoogleService-Info.plist').read_bytes())
        checks['Firebase project'] = firebase.get('PROJECT_ID') == 'negaautism'
        checks['Firebase bundle'] = firebase.get('BUNDLE_ID') == 'org.negaautism.mobile'
        failed = [name for name, passed in checks.items() if not passed]
        if failed:
            raise SystemExit('Export verification failed: ' + ', '.join(failed))
        print('Exported NEGA IPA: strict signature, app/team identity, build, distribution profile, production push and Firebase checks passed')


if __name__ == '__main__':
    verify()
