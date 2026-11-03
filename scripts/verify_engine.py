"""Pinned official Godot 4.5.1 Linux x86_64 release archive digest."""
import hashlib
import sys
from pathlib import Path

expected = '02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd'
with Path(sys.argv[1]).open('rb') as stream:
    digest = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(block)
    actual = digest.hexdigest()
if actual != expected:
    raise SystemExit('Godot archive checksum mismatch')
print('Official Godot engine archive verified')
