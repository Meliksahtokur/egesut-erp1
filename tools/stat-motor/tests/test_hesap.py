import json
from datetime import date, timedelta

import pandas as pd
from lifelines import KaplanMeierFitter

from stat_motor.hesap import fark_zarflari, sagkalim_zarflari, sure_olay

BUGUN = date(2026, 10, 1)
B0 = date(2026, 1, 1)


def satir(i, sonuc, sure, hastalik="mastitis", etiket="P1", bas=B0):
    olay = None if sonuc == "devam" else bas + timedelta(days=sure)
    return {"vaka_id": f"v{i}", "hastalik": hastalik, "protokol_etiket": etiket,
            "baslangic": bas, "sonuc": sonuc, "olay_tarihi": olay}


def df_of(rows):
    return pd.DataFrame(rows)


def test_sure_olay_kurallari():
    df = df_of([satir(1, "iyilesti", 5), satir(2, "devam", 0),
                satir(3, "oldu_kesildi", 7), satir(4, "nuks", 9)])
    r = sure_olay(df, BUGUN)
    assert list(r["sure_gun"]) == [5, (BUGUN - B0).days, 7, 9]
    assert list(r["olay"]) == [True, False, False, False]
    assert r.attrs["dislanan"] == 0


def test_tanimsiz_sure_dislanir():
    rows = [satir(i, "iyilesti", 3 + i) for i in range(6)]
    rows.append({**satir(9, "iyilesti", 0), "olay_tarihi": B0 - timedelta(days=2)})
    rows.append({**satir(10, "iyilesti", 0), "olay_tarihi": None})
    r = sure_olay(df_of(rows), BUGUN)
    assert len(r) == 6 and r.attrs["dislanan"] == 2
    z = sagkalim_zarflari(df_of(rows), BUGUN, "motor:t", "2026-10-01T00:00:00")["mastitis"]
    assert "Süresi tanımsız 2 vaka dahil edilmedi." in z["dipnot"]
    assert z["n"] == 6


def test_km_referans():
    sure = [2, 3, 5, 5, 8, 12]
    sonuc = ["iyilesti", "iyilesti", "oldu_kesildi", "iyilesti", "nuks", "iyilesti"]
    df = df_of([satir(i, s, d) for i, (s, d) in enumerate(zip(sonuc, sure))])
    z = sagkalim_zarflari(df, BUGUN, "motor:t", "2026-10-01T00:00:00")["mastitis"]
    olay = [s == "iyilesti" for s in sonuc]
    kmf = KaplanMeierFitter().fit(sure, olay)
    x = z["x"]["deger"]
    assert z["olcum"] == "stat_tedavi_sagkalim" and z["x"]["ad"] == "gün"
    assert x == list(range(0, 13))
    beklenen = [round(float(1 - kmf.survival_function_at_times(t).iloc[0]), 4) for t in x]
    seri = z["seriler"][0]
    assert seri["ad"] == "P1" and seri["n"] == 6
    assert seri["y"] == beklenen
    ci = kmf.confidence_interval_
    for t, a, u in zip(x, seri["alt"], seri["ust"]):
        satirci = ci[ci.index <= t].iloc[-1]
        assert abs(a - round(1 - satirci.iloc[1], 4)) < 1e-9
        assert abs(u - round(1 - satirci.iloc[0], 4)) < 1e-9
    assert z["tablo"][0]["olay_n"] == 4 and z["tablo"][0]["sansur_n"] == 2
    assert z["tablo"][0]["medyan_gun"] == float(kmf.median_survival_time_)


def test_medyan_ulasilmadi_null():
    rows = [satir(i, "iyilesti", 4 + i) for i in range(2)]
    rows += [satir(10 + i, "devam", 0) for i in range(6)]
    z = sagkalim_zarflari(df_of(rows), BUGUN, "motor:t", "2026-10-01T00:00:00")["mastitis"]
    assert z["tablo"][0]["medyan_gun"] is None
    json.dumps(z, allow_nan=False)
    json.dumps(fark_zarflari(df_of(rows), BUGUN, "motor:t", "x"), allow_nan=False)


def test_n5_alti_seri_null():
    rows = [satir(i, "iyilesti", 3 + i) for i in range(6)]
    rows += [satir(20 + i, "iyilesti", 4 + i, etiket="P2") for i in range(3)]
    z = sagkalim_zarflari(df_of(rows), BUGUN, "motor:t", "x")["mastitis"]
    p2 = [s for s in z["seriler"] if s["ad"] == "P2"][0]
    assert p2["n"] == 3 and p2["y"] is None and p2["alt"] is None and p2["ust"] is None
    t2 = [t for t in z["tablo"] if t["protokol"] == "P2"][0]
    assert t2["yetersiz"] is True and t2["medyan_gun"] is None
    assert z["n"] == 9 and z["yetersiz"] is False
    assert "Karşılaştırma yalnız aynı hastalık içinde anlamlıdır; neden-sonuç değildir." in z["dipnot"]
    assert "Ölüm/kesim ve nüks, olay gününde sansürlendi." in z["dipnot"]


def test_fark_iki_protokol():
    rows = [satir(i, "iyilesti", d) for i, d in enumerate([2, 3, 3, 4, 5, 9])]
    rows += [satir(20 + i, "iyilesti", d, etiket="P2")
             for i, d in enumerate([10, 12, 14, 16, 18, 8])]
    z = fark_zarflari(df_of(rows), BUGUN, "motor:t", "x")["mastitis"]
    assert z["olcum"] == "stat_tedavi_protokol_fark" and z["x"] is None and z["seriler"] == []
    assert len(z["tablo"]) == 1
    t = z["tablo"][0]
    assert (t["a"], t["b"], t["n_a"], t["n_b"]) == ("P1", "P2", 6, 6)
    assert t["logrank_p"] < 0.05
    assert t["hr"] is not None and 0 < t["hr"] < 1 and t["hr_alt"] < t["hr"] < t["hr_ust"]
    json.dumps(z, allow_nan=False)


def test_fark_tek_protokol_yetersiz():
    rows = [satir(i, "iyilesti", 3 + i) for i in range(6)]
    rows += [satir(20 + i, "iyilesti", 4 + i, etiket="P2") for i in range(3)]
    z = fark_zarflari(df_of(rows), BUGUN, "motor:t", "x")["mastitis"]
    assert z["yetersiz"] is True and z["tablo"] == []


def test_deterministik():
    rows = [satir(i, "iyilesti", 3 + i) for i in range(6)]
    rows += [satir(20 + i, "nuks", 4 + i, etiket="P2") for i in range(6)]
    a = df_of(rows)
    j1 = json.dumps([sagkalim_zarflari(a, BUGUN, "s", "h"), fark_zarflari(a, BUGUN, "s", "h")], sort_keys=True)
    j2 = json.dumps([sagkalim_zarflari(a.copy(), BUGUN, "s", "h"), fark_zarflari(a.copy(), BUGUN, "s", "h")], sort_keys=True)
    assert j1 == j2
