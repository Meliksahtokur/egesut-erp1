"""Kosum akisi (spec 7.1 Sekil 4): kilit -> ozet -> fark -> delta cek -> hesap -> yaz -> commit -> onbellek."""
from __future__ import annotations

import re
from datetime import date, datetime
from zoneinfo import ZoneInfo

import pandas as pd

from .db import KOLONLAR
from .hesap import fark_zarflari, sagkalim_zarflari
from .onbellek import KilitMesgul, Onbellek, fark, girdi_ozeti

OLCUMLER = (("stat_tedavi_sagkalim", sagkalim_zarflari), ("stat_tedavi_protokol_fark", fark_zarflari))


def bugun_istanbul() -> date:
    return datetime.now(ZoneInfo("Europe/Istanbul")).date()


def _temiz(e: Exception) -> str:
    """Istisna metni: DSN benzeri dizgiler maskelenir, 500 karaktere kesilir."""
    metin = re.sub(r"\w+://\S+", "<dsn>", f"{type(e).__name__}: {e}")
    return metin[:500]


def calistir(depo, onbellek: Onbellek, bugun: date, surum: str, force: bool = False) -> str:
    try:
        with onbellek.kilit():
            return _akis(depo, onbellek, bugun, surum, force)
    except KilitMesgul as e:
        depo.kosum_kapat(depo.kosum_ac(), "atlandi", str(e), {})
        return "atlandi"


def _akis(depo, onbellek: Onbellek, bugun: date, surum: str, force: bool) -> str:
    kosum_id = depo.kosum_ac()
    try:
        eski_ozet, eski_df = onbellek.oku()
        yeni_ozet = depo.ozet()
        f = fark(eski_ozet, yeni_ozet)
        if f.bos and not force:
            depo.kosum_kapat(kosum_id, "atlandi", "değişiklik yok", {})
            return "atlandi"
        ids = sorted(f.yeni | f.degisen)
        df = _birlestir(eski_df, depo.satirlar(ids) if ids else None, f.degisen | f.kaybolan, yeni_ozet)
        hesap_at = datetime.now(ZoneInfo("Europe/Istanbul")).isoformat(timespec="seconds")
        ozet_md5 = girdi_ozeti(yeni_ozet)
        for olcum, hesapla in OLCUMLER:
            zarflar = hesapla(df, bugun, surum, hesap_at) if len(df) else {}
            depo.yaz(olcum, zarflar, ozet_md5, surum)
        depo.commit()
        onbellek.yaz(yeni_ozet, df)  # RF 1: yalniz DB commit'inden sonra
        depo.kosum_kapat(kosum_id, "ok", None, {"tedavi_vaka": {
            "yeni": len(f.yeni), "degisen": len(f.degisen), "kaybolan": len(f.kaybolan)}})
        return "ok"
    except Exception as e:
        depo.rollback()
        depo.kosum_kapat(kosum_id, "hata", _temiz(e), {})
        return "hata"


def _birlestir(eski: pd.DataFrame, yeni: pd.DataFrame | None, cikar: set[str], ozet: dict) -> pd.DataFrame:
    """vaka_id anahtarli REPLACE: degisen/kaybolan eski satirlar duser, yeni cekilenler girer."""
    parcalar = []
    if len(eski):
        parcalar.append(eski[~eski["vaka_id"].isin(cikar) & eski["vaka_id"].isin(ozet)])
    if yeni is not None and len(yeni):
        parcalar.append(yeni)
    if not parcalar:
        return pd.DataFrame(columns=KOLONLAR)
    return pd.concat(parcalar, ignore_index=True).sort_values("vaka_id", ignore_index=True)
