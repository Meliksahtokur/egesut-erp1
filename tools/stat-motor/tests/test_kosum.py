import hashlib
import os
import threading
from datetime import date, timedelta

import pandas as pd
import pytest

from stat_motor import db, kosum
from stat_motor.onbellek import Onbellek

BUGUN = date(2026, 10, 1)
B0 = date(2026, 1, 1)


def vaka(i, hastalik="mastitis", etiket="P1", sonuc="iyilesti", sure=4):
    olay = None if sonuc == "devam" else B0 + timedelta(days=sure)
    return {"vaka_id": f"v{i}", "hastalik": hastalik, "protokol_etiket": etiket,
            "baslangic": B0, "sonuc": sonuc, "olay_tarihi": olay}


def kume(hastalik="mastitis", n=12, baslangic=0):
    return [vaka(i, hastalik, "P1" if i % 2 else "P2", sure=3 + i % 5)
            for i in range(baslangic, baslangic + n)]


class SahteDepo:
    def __init__(self, satirlar, yaz_hata=False):
        self.kaynak = {s["vaka_id"]: s for s in satirlar}
        self.yaz_hata = yaz_hata
        self.cekilen = []
        self.sonuc: dict[tuple[str, str], dict] = {}
        self.bekleyen = None
        self.defter = []

    def ozet(self):
        return {k: hashlib.md5(repr(sorted(v.items(), key=str)).encode()).hexdigest()
                for k, v in self.kaynak.items()}

    def satirlar(self, ids):
        self.cekilen.append(sorted(ids))
        return pd.DataFrame([self.kaynak[i] for i in ids])

    def kosum_ac(self):
        self.defter.append({"durum": None, "mesaj": None, "degisen": None})
        return len(self.defter) - 1

    def kosum_kapat(self, id, durum, mesaj, degisen):
        self.defter[id] = {"durum": durum, "mesaj": mesaj, "degisen": degisen}

    def yaz(self, olcum, zarflar, girdi_ozeti, motor_surum):
        if self.bekleyen is None:
            self.bekleyen = dict(self.sonuc)
        if self.yaz_hata:
            raise RuntimeError("yazma patladi")
        for k in [k for k in self.bekleyen if k[0] == olcum]:
            del self.bekleyen[k]
        for h, z in zarflar.items():
            self.bekleyen[(olcum, h)] = {"sonuc": z, "girdi_ozeti": girdi_ozeti,
                                         "motor_surum": motor_surum}

    def commit(self):
        if self.bekleyen is not None:
            self.sonuc, self.bekleyen = self.bekleyen, None

    def rollback(self):
        self.bekleyen = None


def calistir(depo, tmp_path, force=False):
    return kosum.calistir(depo, Onbellek(tmp_path, "t", "tedavi_vaka"), BUGUN, "motor:t", force=force)


def sonuc_ozeti(depo):
    return {k: ({a: b for a, b in v["sonuc"].items() if a != "hesap_at"}, v["girdi_ozeti"])
            for k, v in depo.sonuc.items()}


def test_ilk_kosum_ok_ve_onbellek(tmp_path):
    depo = SahteDepo(kume())
    assert calistir(depo, tmp_path) == "ok"
    ozet, df = Onbellek(tmp_path, "t", "tedavi_vaka").oku()
    assert len(ozet) == 12 and len(df) == 12
    assert {k[0] for k in depo.sonuc} == {"stat_tedavi_sagkalim", "stat_tedavi_protokol_fark"}
    assert depo.defter[-1]["durum"] == "ok"
    assert depo.defter[-1]["degisen"] == {"tedavi_vaka": {"yeni": 12, "degisen": 0, "kaybolan": 0}}


def test_ikinci_kosum_atlandi(tmp_path):
    depo = SahteDepo(kume())
    calistir(depo, tmp_path)
    onceki = dict(depo.sonuc)
    assert calistir(depo, tmp_path) == "atlandi"
    assert depo.defter[-1]["durum"] == "atlandi"
    assert depo.sonuc == onceki


def test_force_ayni_sonuc(tmp_path):
    depo = SahteDepo(kume())
    calistir(depo, tmp_path)
    ilk = sonuc_ozeti(depo)
    assert calistir(depo, tmp_path, force=True) == "ok"
    assert sonuc_ozeti(depo) == ilk


def test_degisen_yalniz_delta_ceker(tmp_path):
    depo = SahteDepo(kume())
    calistir(depo, tmp_path)
    depo.cekilen.clear()
    depo.kaynak["v3"] = {**depo.kaynak["v3"], "sonuc": "nuks"}
    depo.kaynak["v99"] = vaka(99)
    assert calistir(depo, tmp_path) == "ok"
    assert depo.cekilen == [["v3", "v99"]]
    _, df = Onbellek(tmp_path, "t", "tedavi_vaka").oku()
    assert len(df) == 13 and df["vaka_id"].is_unique
    assert df.loc[df["vaka_id"] == "v3", "sonuc"].item() == "nuks"
    assert depo.defter[-1]["degisen"] == {"tedavi_vaka": {"yeni": 1, "degisen": 1, "kaybolan": 0}}


def test_onbellek_commit_sonrasi(tmp_path):
    depo = SahteDepo(kume())
    calistir(depo, tmp_path)
    eski_ozet, _ = Onbellek(tmp_path, "t", "tedavi_vaka").oku()
    eski_sonuc = dict(depo.sonuc)
    depo.kaynak["v99"] = vaka(99)
    depo.yaz_hata = True
    assert calistir(depo, tmp_path) == "hata"
    assert Onbellek(tmp_path, "t", "tedavi_vaka").oku()[0] == eski_ozet
    assert depo.sonuc == eski_sonuc
    assert depo.defter[-1]["durum"] == "hata" and "yazma patladi" in depo.defter[-1]["mesaj"]


def test_kaybolan_anahtar_silinir(tmp_path):
    depo = SahteDepo(kume("mastitis") + kume("metritis", baslangic=100))
    calistir(depo, tmp_path)
    assert ("stat_tedavi_sagkalim", "metritis") in depo.sonuc
    for k in [k for k in depo.kaynak if int(k[1:]) >= 100]:
        del depo.kaynak[k]
    assert calistir(depo, tmp_path) == "ok"
    assert not [k for k in depo.sonuc if k[1] == "metritis"]
    assert ("stat_tedavi_sagkalim", "mastitis") in depo.sonuc
    assert depo.defter[-1]["degisen"]["tedavi_vaka"]["kaybolan"] == 12


def test_es_zamanli_kilit(tmp_path):
    depo = SahteDepo(kume())
    ob = Onbellek(tmp_path, "t", "tedavi_vaka")
    with ob.kilit():
        sonuc = []
        t = threading.Thread(target=lambda: sonuc.append(calistir(depo, tmp_path)))
        t.start()
        t.join()
    assert sonuc == ["atlandi"]
    assert depo.defter[-1]["durum"] == "atlandi" and depo.defter[-1]["mesaj"].startswith("kilit")
    assert not depo.sonuc


def test_env_izin_600(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    d = tmp_path / ".config" / "stat-motor"
    d.mkdir(parents=True)
    f = d / "x.env"
    f.write_text("STAT_MOTOR_DSN=postgresql://u:gizliparola@h/db\n")
    os.chmod(f, 0o644)
    with pytest.raises(PermissionError) as e:
        db.dsn_oku("x")
    assert "600" in str(e.value) and "gizliparola" not in str(e.value)
    os.chmod(f, 0o600)
    assert db.dsn_oku("x") == "postgresql://u:gizliparola@h/db"
