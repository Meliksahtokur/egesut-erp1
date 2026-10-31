"""Hash-diff onbellegi (spec 7.1-7.2): parquet + ozet.json, atomik yazim, fcntl kilidi."""

import fcntl
import hashlib
import json
import os
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

VARSAYILAN_KOK = Path.home() / ".cache" / "stat-motor"


class KilitMesgul(RuntimeError):
    pass


@dataclass
class Fark:
    yeni: set[str]
    degisen: set[str]
    kaybolan: set[str]

    @property
    def bos(self) -> bool:
        return not (self.yeni or self.degisen or self.kaybolan)


def fark(eski: dict[str, str], yeni: dict[str, str]) -> Fark:
    return Fark(
        yeni={k for k in yeni if k not in eski},
        degisen={k for k in yeni if k in eski and eski[k] != yeni[k]},
        kaybolan={k for k in eski if k not in yeni},
    )


def girdi_ozeti(ozet: dict[str, str]) -> str:
    metin = "\n".join(f"{i}:{h}" for i, h in sorted(ozet.items()))
    return hashlib.md5(metin.encode()).hexdigest()


class Onbellek:
    def __init__(self, kok: Path | None, profil: str, kume: str):
        self.dizin = Path(kok or VARSAYILAN_KOK) / profil / kume
        self.parquet = self.dizin / "vakalar.parquet"
        self.ozet = self.dizin / "ozet.json"

    def _sil(self) -> None:
        for p in (self.parquet, self.ozet):
            p.unlink(missing_ok=True)

    def oku(self) -> tuple[dict[str, str], pd.DataFrame]:
        if not (self.parquet.exists() and self.ozet.exists()):
            self._sil()
            return {}, pd.DataFrame()
        try:
            ozet = json.loads(self.ozet.read_text())
            df = pd.read_parquet(self.parquet)
            if not isinstance(ozet, dict):
                raise ValueError("ozet sozluk degil")
            return ozet, df
        except Exception:
            self._sil()
            return {}, pd.DataFrame()

    def yaz(self, ozet: dict[str, str], df: pd.DataFrame) -> None:
        self.dizin.mkdir(parents=True, exist_ok=True)
        gp, go = self.parquet.with_suffix(".parquet.tmp"), self.ozet.with_suffix(".json.tmp")
        try:
            df.to_parquet(gp)
            go.write_text(json.dumps(ozet))
            os.replace(gp, self.parquet)
            os.replace(go, self.ozet)
        finally:
            gp.unlink(missing_ok=True)
            go.unlink(missing_ok=True)

    @contextmanager
    def kilit(self):
        self.dizin.mkdir(parents=True, exist_ok=True)
        with open(self.dizin / ".kilit", "w") as f:
            try:
                fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as e:
                raise KilitMesgul("kilit: başka koşum sürüyor") from e
            try:
                yield
            finally:
                fcntl.flock(f, fcntl.LOCK_UN)
