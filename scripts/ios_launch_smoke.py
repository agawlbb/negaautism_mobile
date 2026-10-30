"""Launch the real iOS app on a clean simulator before publishing to TestFlight."""
import json
import os
from pathlib import Path
import re
import subprocess
import time


def run(*args, timeout=180):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=timeout).strip()
    except subprocess.CalledProcessError as error:
        print(error.output, flush=True)
        raise


def main():
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    candidates = [(runtime, device) for runtime, group in devices.items()
                  if '.iOS-' in runtime for device in group
                  if device['isAvailable'] and device['name'].startswith('iPhone')]
    if not candidates:
        raise SystemExit('No available iPhone simulator')
    runtime, device = sorted(candidates, key=lambda item: (item[0], 'Pro' in item[1]['name']), reverse=True)[0]
    print('Launch smoke test: ' + device['name'] + ' / ' + runtime, flush=True)
    udid = device['udid']
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', udid)
    simulator = Path(run('xcode-select', '-p')) / 'Applications/Simulator.app'
    if simulator.is_dir():
        run('open', '-a', str(simulator), '--args', '-CurrentDeviceUDID', udid)
    else:
        print('Runner has no Simulator.app; validating app startup with headless simctl.', flush=True)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=600)
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
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        raise SystemExit('iOS app exited during startup; refusing TestFlight publication') from None
    try:
        run('xcrun', 'simctl', 'io', udid, 'screenshot', str((folder / 'launch.png').resolve()), timeout=30)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        print('::warning::Simulator display capture unavailable; app process survival passed, visual validation remains pending.', flush=True)
    print('iOS app remained running for 20 seconds after startup.', flush=True)


if __name__ == '__main__':
    main()
