#!/usr/bin/env python3
"""Exercise atomic replacement, continuous reads and failure preservation."""
from pathlib import Path
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='glass-install-test-') as directory:
    tmp = Path(directory)
    installer = tmp/'atomic-install'
    subprocess.run(['swiftc', '-parse-as-library', str(ROOT/'Tools/AtomicInstall.swift'), '-o', str(installer)], check=True)
    stage, destination = tmp/'stage.app', tmp/'installed.app'
    stage.mkdir()
    (stage/'version').write_text('old')
    subprocess.run([str(installer), str(stage), str(destination)], check=True)
    assert not stage.exists() and (destination/'version').read_text() == 'old'
    stage.mkdir()
    (stage/'version').write_text('new')
    errors, stop = [], threading.Event()
    def reader():
        while not stop.is_set():
            try:
                assert (destination/'version').read_text() in ('old', 'new')
            except Exception as exc:
                errors.append(str(exc))
            time.sleep(0.001)
    thread = threading.Thread(target=reader)
    thread.start()
    try:
        for _ in range(20):
            subprocess.run([str(installer), str(stage), str(destination)], check=True)
    finally:
        stop.set()
        thread.join()
    assert not errors, errors
    before = (destination/'version').read_bytes()
    failure = subprocess.run([str(installer), str(tmp/'missing.app'), str(destination)], capture_output=True)
    assert failure.returncode != 0
    assert (destination/'version').read_bytes() == before
print('PASS atomic install: fresh install, continuous reads during replacement, failure preserves app')
