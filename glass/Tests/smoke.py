#!/usr/bin/env python3
"""macOS connection/lifecycle tests; real dsh uses an isolated DSH_HOME."""
import http.server
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]

def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]

with tempfile.TemporaryDirectory(prefix='glass-smoke-') as directory:
    tmp = Path(directory)
    binary = tmp / 'connection-smoke'
    subprocess.run(['swiftc', '-parse-as-library', str(ROOT/'Sources/BackendController.swift'),
                    str(ROOT/'Tests/ConnectionSmoke.swift'), '-o', str(binary)], check=True)
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            authorized = self.path == '/?token=fixture'
            self.send_response(200 if authorized else 401)
            self.end_headers()
            self.wfile.write(b'<script>window.__DSH_BOOT__={}</script>' if authorized
                             else b'dsh web authentication required; reopen the URL printed by dsh web.\n')
        def log_message(self, *args):
            pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    def run(mode, port, executable=None, extra=()):
        env = dict(os.environ, DSH_HOME=str(tmp / mode), DSH_WEB_URL=f'http://127.0.0.1:{port}/')
        if executable:
            env['DSH_EXECUTABLE'] = str(executable)
        subprocess.run([str(binary), mode, *extra], env=env, check=True, timeout=90)
    try:
        run('unauthorized', server.server_port)
        run('connect', server.server_port, extra=(f'http://127.0.0.1:{server.server_port}/?token=fixture',))
        # An external process must still answer after controller shutdown.
        with urllib.request.urlopen(f'http://127.0.0.1:{server.server_port}/?token=fixture') as response:
            assert response.status == 200
    finally:
        server.shutdown()
        server.server_close()
    class OtherService(Handler):
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Not a dsh server')
    other = http.server.ThreadingHTTPServer(('127.0.0.1', 0), OtherService)
    threading.Thread(target=other.serve_forever, daemon=True).start()
    try:
        run('occupied', other.server_port)
    finally:
        other.shutdown()
        other.server_close()
    run('missing', free_port(), tmp/'does-not-exist')
    fixture = tmp/'dsh'
    fixture.write_text('''#!/usr/bin/env python3
import os, signal, sys, time
from pathlib import Path
assert sys.argv[1:5] == ['web', '--no-open', '--host', '127.0.0.1']
p = Path(os.environ['DSH_HOME']); p.mkdir(parents=True, exist_ok=True)
p.joinpath('pid').write_text(str(os.getpid()))
print('dsh web: http://127.0.0.1:' + os.environ['GLASS_DSH_PORT'] + '/?token=split-', end='', flush=True)
time.sleep(0.15)
print('token-complete', flush=True)
while True: time.sleep(1)
''')
    fixture.chmod(0o755)
    run('spawn', free_port(), fixture)
    pid = int((tmp/'spawn/pid').read_text())
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        pass
    else:
        raise AssertionError('Owned dsh survived shutdown')
    if os.environ.get('GLASS_TEST_REAL_DSH') == '1':
        port = free_port()
        run('real', port)
        with socket.socket() as sock:
            assert sock.connect_ex(('127.0.0.1', port)) != 0, 'Real dsh survived shutdown'
print('All connection smoke tests passed')
