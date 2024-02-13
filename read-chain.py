#!/usr/bin/env python3

from pathlib import Path
from typing import List
import tempfile
import subprocess
import sys

def cert_detail(cert_files: List[Path]) -> None:
    for ix, p in enumerate(cert_files):
        p = subprocess.run(f"openssl x509 -text -noout -in {str(p)}".split(), shell=False, check=True, encoding="ascii", capture_output=True)

        print(f"***---- {ix}\n{p.stdout}", file=sys.stdout)

def write_certs(certs: List[str], tmpdir: Path) -> List[Path]:
    paths = []

    for ix, c in enumerate(certs):
        p = Path(tmpdir, f"{ix}.pem")
        with open(p, 'w') as outf:
            outf.writelines(c)
        paths.append(p)

    return paths

def parse_certs(inf) -> List[str]:
    certs = []
    lines = []

    for line in inf:
        line = line.strip()
        lines.append(line)
        if line == "-----END CERTIFICATE-----":
            certs.append("\n".join(lines))
            lines = []
    return certs


cert_file = sys.argv[1]

with tempfile.TemporaryDirectory() as tmpdir:
    with open(cert_file, 'r') as inf:
        certs = parse_certs(inf)
        cert_files = write_certs(certs, tmpdir)
        cert_detail(cert_files)

