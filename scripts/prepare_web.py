"""Wrap the actual Godot export in a responsive browser shell."""
from pathlib import Path
from urllib.parse import urlparse
import json
import gzip
import os
import re
import shutil

root = Path(__file__).resolve().parent.parent
out = root / 'builds/web'
export = (out / 'index.html').read_text()
match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', export)
if not match:
    raise SystemExit('Godot export configuration missing; export the game first')
config = json.loads(match[1])
url = os.environ.get('SKYBREAK_LOBBY_URL', 'http://127.0.0.1:3000').rstrip('/')
parsed = urlparse(url)
if parsed.scheme not in ('http', 'https') or not parsed.netloc or parsed.path or parsed.query or parsed.username:
    raise SystemExit('SKYBREAK_LOBBY_URL must be the HTTP(S) origin of the lobby')
if os.environ.get('VERCEL') and (parsed.scheme != 'https' or parsed.hostname in ('localhost', '127.0.0.1')):
    raise SystemExit('Set SKYBREAK_LOBBY_URL to the live HTTPS Render server before deploying')
development = os.environ.get('SKYBREAK_DEV') == '1' and not os.environ.get('VERCEL')
shell = (root / 'website/index.template.html').read_text()
(out / 'index.html').write_text(shell.replace('__GODOT_CONFIG__', json.dumps(config)))
for name in ('client.js', 'site.css'):
    shutil.copy2(root / 'website' / name, out / name)
(out / 'lobby.json').write_text(json.dumps({'lobbyUrl': url, 'version': '1.2.0', 'development': development}))
(out / 'index.wasm.gz').write_bytes(gzip.compress((out / 'index.wasm').read_bytes(), compresslevel=9, mtime=0))
print('Browser game prepared; development controls:', development)
