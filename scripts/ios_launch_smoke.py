"""Launch the real iOS app on a clean simulator before publishing to TestFlight."""
import json
import os
from pathlib import Path
import re
import subprocess
import time


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()


def main():
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    candidates = [(runtime, device) for runtime, group in devices.items()
                  if '.iOS-' in runtime for device in group
                  if device['isAvailable'] and device['name'].startswith('iPhone')]
    if not candidates:
        raise SystemExit('No available iPhone simulator')
    runtime, device = sorted(candidates, key=lambda item: item[0], reverse=True)[0]
    print('Launch smoke test: ' + device['name'] + ' / ' + runtime, flush=True)
    udid = device['udid']
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', udid)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    app = Path('build/ios/iphonesimulator/Runner.app')
    if not app.is_dir():
        raise SystemExit('Build the simulator app first')
    run('xcrun', 'simctl', 'install', udid, str(app))
    output = run('xcrun', 'simctl', 'launch', '--terminate-running-process', udid, 'org.negaautism.mobile')
    match = re.search(r'org\.negaautism\.mobile:\s*(\d+)', output)
    if not match:
        raise SystemExit('Simulator did not return an app process ID')
    pid = int(match[1])
    time.sleep(20)
    folder = Path('build/ios/launch-smoke')
    folder.mkdir(parents=True, exist_ok=True)
    run('xcrun', 'simctl', 'io', udid, 'screenshot', str(folder / 'launch.png'))
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        raise SystemExit('iOS app exited during startup; refusing TestFlight publication') from None
    print('iOS app remained running after startup; launch screenshot captured.', flush=True)


if __name__ == '__main__':
    main()
