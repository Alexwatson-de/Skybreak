"""A match endpoint that appears after the first connection attempt must recover."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
engine = os.environ.get('GODOT_BIN', str(root / '.runtime/Godot.app/Contents/MacOS/Godot'))
with tempfile.TemporaryDirectory(prefix='skybreak-join-') as temporary:
    folder = Path(temporary)
    roster = folder / 'roster.json'
    roster.write_text(json.dumps([dict(id=1, name='RetryPilot', team=0, char=0, token='retry-fixture')]))
    processes = []
    with (folder / 'client.log').open('w') as log, (folder / 'server.log').open('w') as server_log:
        def start(flags, stream):
            process = subprocess.Popen([engine, '--headless', '--path', str(root / 'game'), '--', *flags], stdout=stream, stderr=subprocess.STDOUT)
            processes.append(process)
            return process
        try:
            client = start(['--websocket=ws://127.0.0.1:29919', '--token=retry-fixture', '--seconds=7', f'--report={folder}/report.json'], log)
            time.sleep(1.2)
            start(['--server', '--transport=websocket', '--port=29919', f'--roster={roster}', '--seconds=9'], server_log)
            assert client.wait(timeout=15) == 0
            report = json.loads((folder / 'report.json').read_text())
            assert report['local_id'] == 1, report
            assert report['metrics']['snapshots'] > 40, report
            assert report['metrics']['reconnects'] == 0, report
            assert 'SCRIPT ERROR' not in (folder / 'client.log').read_text()
            (root / 'docs/join-retry-test-evidence.json').write_text(json.dumps(report, indent=2))
            print('JOIN RETRY PASSED: refused first attempt -> delayed server -> authenticated snapshots')
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
