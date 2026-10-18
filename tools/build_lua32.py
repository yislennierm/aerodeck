"""Build Lua5.3.6 with int32/float32 in .build/ (macOS/Linux, C compiler/make).

Downloads the official Lua source and verifies its published SHA256. No system
installation or package-manager changes. The resulting interpreter is test-only.
"""
from pathlib import Path
import hashlib
import io
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SHA = 'fc5fd69bb8736323f026672b1b7235da613d7177e72558893a0bdcd320466d60'


def main():
    if not shutil.which('make') or not shutil.which(os.environ.get('CC', 'cc')):
        raise SystemExit('Install a C compiler and make first')
    out = ROOT / '.build'
    out.mkdir(exist_ok=True)
    archive = out / 'lua-5.3.6.tar.gz'
    if not archive.exists():
        with urllib.request.urlopen('https://www.lua.org/ftp/lua-5.3.6.tar.gz', timeout=60) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != SHA:
            raise SystemExit('Official Lua source checksum mismatch')
        archive.write_bytes(data)
    data = archive.read_bytes()
    if hashlib.sha256(data).hexdigest() != SHA:
        raise SystemExit('Cached Lua source checksum mismatch')
    source = out / 'lua-5.3.6'
    if not source.exists():
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
            for item in tar.getmembers():
                name = Path(item.name)
                if name.is_absolute() or '..' in name.parts or item.issym() or item.islnk():
                    raise SystemExit('Unsafe Lua source archive entry')
            tar.extractall(out, filter='data')
    # Lua's generic target avoids a readline dependency. POSIX/dlopen are unused
    # by these portable tests; numeric settings match the firmware representation.
    subprocess.run(['make', 'clean'], cwd=source, check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['make', 'generic', 'MYCFLAGS=-DLUA_32BITS=1', '-j2'], cwd=source, check=True)
    binary = source / 'src/lua'
    probe = subprocess.check_output([str(binary), '-e', "print(string.packsize('j'),string.packsize('n'))"], text=True)
    if probe.split() != ['4', '4']:
        raise SystemExit('Built interpreter is not int32/float32')
    print(binary)


if __name__ == '__main__':
    main()
