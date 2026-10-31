"""Saf (DB'siz) hesap: Kaplan-Meier iyilesme egrisi ve protokol farki (spec 5.3, 8.1)."""
from __future__ import annotations

import math
import warnings
from datetime import date
from itertools import combinations

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter, KaplanMeierFitter
from lifelines.statistics import logrank_test
from lifelines.utils import median_survival_times

MIN_N = 5
NOT_SANSUR = "Ölüm/kesim ve nüks, olay gününde sansürlendi."
NOT_KARSILASTIRMA = "Karşılaştırma yalnız aynı hastalık içinde anlamlıdır; neden-sonuç değildir."


def _f(v, hane=4):
    """numpy/inf/NaN -> Python float ya da None."""
    if v is None:
        return None
    v = float(v)
    return round(v, hane) if math.isfinite(v) else None


def sure_olay(df: pd.DataFrame, bugun: date) -> pd.DataFrame:
    """Satir basina sure_gun/olay. Suresi tanimsiz (NULL ya da <0) satirlar disarida;
    sayi `attrs['dislanan']`. K16: oldu_kesildi ve nuks olay gununde sansurlenir."""
    bas = pd.to_datetime(df["baslangic"])
    son = pd.to_datetime(df["olay_tarihi"])
    devam = df["sonuc"] == "devam"
    bitis = son.where(~devam, pd.Timestamp(bugun))
    sure = (bitis - bas).dt.days
    gecerli = sure.notna() & (sure >= 0)
    out = df.loc[gecerli].copy()
    out["sure_gun"] = sure[gecerli].astype(int)
    out["olay"] = (df.loc[gecerli, "sonuc"] == "iyilesti").astype(bool)
    out.attrs["dislanan"] = int((~gecerli).sum())
    return out


def _dipnot(dislanan: int) -> list[str]:
    d = [NOT_SANSUR]
    if dislanan > 0:
        d.append(f"Süresi tanımsız {dislanan} vaka dahil edilmedi.")
    d.append(NOT_KARSILASTIRMA)
    return d


def _hastaliklar(df: pd.DataFrame, bugun: date):
    """(hastalik, gecerli satirlar, dislanan) uclusu, hastalik adina gore sirali."""
    tum = sure_olay(df, bugun)
    for h in sorted(df["hastalik"].unique()):
        n_girdi = int((df["hastalik"] == h).sum())
        g = tum[tum["hastalik"] == h]
        yield h, g, n_girdi - len(g)


def _zarf(olcum, hesap_at, surum, n, x, seriler, tablo, dipnot):
    return {"olcum": olcum, "hesap_at": hesap_at, "surum": surum, "n": int(n),
            "yetersiz": n < MIN_N, "x": x, "seriler": seriler, "tablo": tablo, "dipnot": dipnot}


def _kumulatif(kmf: KaplanMeierFitter, grid: list[int]):
    """1-S(t) ve 1-GA (alt, ust) degerleri, adim fonksiyonu olarak grid'de."""
    ci = kmf.confidence_interval_
    idx = ci.index.values
    pos = np.searchsorted(idx, np.asarray(grid), side="right") - 1
    s = kmf.survival_function_at_times(grid).values
    lo = ci.iloc[:, 0].values[pos]  # S icin alt sinir -> kumulatifte ust
    hi = ci.iloc[:, 1].values[pos]
    return ([_f(1 - v) for v in s], [_f(1 - v) for v in hi], [_f(1 - v) for v in lo])


def sagkalim_zarflari(df, bugun: date, surum: str, hesap_at: str) -> dict[str, dict]:
    sonuc = {}
    for h, g, dislanan in _hastaliklar(df, bugun):
        maks = int(g["sure_gun"].max()) if len(g) else 0
        grid = list(range(0, maks + 1))
        seriler, tablo = [], []
        for etiket in sorted(g["protokol_etiket"].unique()):
            s = g[g["protokol_etiket"] == etiket]
            n, olay_n = len(s), int(s["olay"].sum())
            satir = {"protokol": etiket, "n": n, "olay_n": olay_n, "sansur_n": n - olay_n,
                     "medyan_gun": None, "medyan_alt": None, "medyan_ust": None,
                     "yetersiz": n < MIN_N}
            seri = {"ad": etiket, "n": n, "y": None, "alt": None, "ust": None}
            if n >= MIN_N:
                kmf = KaplanMeierFitter().fit(s["sure_gun"], s["olay"])
                seri["y"], seri["alt"], seri["ust"] = _kumulatif(kmf, grid)
                satir["medyan_gun"] = _f(kmf.median_survival_time_)
                mci = median_survival_times(kmf.confidence_interval_)
                satir["medyan_alt"], satir["medyan_ust"] = _f(mci.iloc[0, 0]), _f(mci.iloc[0, 1])
            seriler.append(seri)
            tablo.append(satir)
        sonuc[h] = _zarf("stat_tedavi_sagkalim", hesap_at, surum, len(g),
                         {"ad": "gün", "deger": grid}, seriler, tablo, _dipnot(dislanan))
    return sonuc


def _cox_hr(a: pd.DataFrame, b: pd.DataFrame):
    """(hr, alt, ust) ya da None: b grubu ikili degisken, hr=exp(coef)."""
    if int(a["olay"].sum()) == 0 or int(b["olay"].sum()) == 0:
        return None
    d = pd.concat([a.assign(b=0), b.assign(b=1)])[["sure_gun", "olay", "b"]].astype(float)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error")
            ozet = CoxPHFitter().fit(d, "sure_gun", "olay").summary.loc["b"]
    except Exception:  # yakinsama / tekillik / uyari -> HR yok
        return None
    degerler = (_f(ozet["exp(coef)"]), _f(ozet["exp(coef) lower 95%"]), _f(ozet["exp(coef) upper 95%"]))
    return degerler if None not in degerler else None


def fark_zarflari(df, bugun: date, surum: str, hesap_at: str) -> dict[str, dict]:
    sonuc = {}
    for h, g, dislanan in _hastaliklar(df, bugun):
        uygun = [e for e in sorted(g["protokol_etiket"].unique())
                 if (g["protokol_etiket"] == e).sum() >= MIN_N]
        dipnot = _dipnot(dislanan)
        tablo = []
        if len(uygun) >= 2:
            for ea, eb in combinations(uygun, 2):
                a, b = g[g["protokol_etiket"] == ea], g[g["protokol_etiket"] == eb]
                p = logrank_test(a["sure_gun"], b["sure_gun"], a["olay"], b["olay"]).p_value
                hr = _cox_hr(a, b) or (None, None, None)
                if hr[0] is None:
                    dipnot.append(f"HR hesaplanamadı ({ea}–{eb}).")
                tablo.append({"a": ea, "b": eb, "n_a": len(a), "n_b": len(b), "logrank_p": _f(p),
                              "hr": hr[0], "hr_alt": hr[1], "hr_ust": hr[2]})
        z = _zarf("stat_tedavi_protokol_fark", hesap_at, surum, len(g), None, [], tablo, dipnot)
        z["yetersiz"] = len(uygun) < 2
        sonuc[h] = z
    return sonuc
