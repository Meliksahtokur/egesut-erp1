"""stat-motor run --profil {demo,prod} [--force]"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from . import db, kosum
from .onbellek import Onbellek


def surum_bul() -> str:
    kok = Path(__file__).resolve().parents[3]
    try:
        sha = subprocess.run(["git", "-C", str(kok), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, check=True, timeout=10).stdout.strip()
        return f"motor:{sha}" if sha else "motor:yerel"
    except (OSError, subprocess.SubprocessError):
        return "motor:yerel"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="stat-motor")
    alt = p.add_subparsers(dest="komut", required=True)
    r = alt.add_parser("run")
    r.add_argument("--profil", choices=["demo", "prod"], required=True)
    r.add_argument("--force", action="store_true")
    a = p.parse_args(argv)
    surum = surum_bul()
    try:
        conn = db.baglan(a.profil)
    except (OSError, KeyError, RuntimeError) as e:
        print(f"hata: {type(e).__name__}", file=sys.stderr)
        return 1
    with conn:
        sonuc = kosum.calistir(db.PgDepo(conn, surum), Onbellek(None, a.profil, "tedavi_vaka"),
                               kosum.bugun_istanbul(), surum, force=a.force)
    print(sonuc)
    return 1 if sonuc == "hata" else 0


if __name__ == "__main__":
    sys.exit(main())
