import pandas as pd
import pytest

from stat_motor import onbellek
from stat_motor.onbellek import Fark, KilitMesgul, Onbellek, fark, girdi_ozeti


def test_fark_uc_kume():
    f = fark({"a": "1", "b": "2", "c": "3"}, {"b": "2", "c": "9", "d": "4"})
    assert f == Fark(yeni={"d"}, degisen={"c"}, kaybolan={"a"})
    assert not f.bos


def test_fark_bos():
    f = fark({"a": "1"}, {"a": "1"})
    assert f.bos and f.yeni == f.degisen == f.kaybolan == set()


def test_girdi_ozeti_sira_bagimsiz():
    assert girdi_ozeti({"a": "1", "b": "2"}) == girdi_ozeti({"b": "2", "a": "1"})
    assert girdi_ozeti({"a": "1"}) != girdi_ozeti({"a": "2"})


def test_bozuk_dosya_tam_cekime_doner(tmp_path):
    o = Onbellek(tmp_path, "demo", "k")
    o.yaz({"x": "h"}, pd.DataFrame({"vaka_id": ["x"]}))
    pq = next(tmp_path.rglob("*.parquet"))
    pq.write_bytes(b"cop bayt")
    ozet, df = o.oku()
    assert ozet == {} and df.empty
    assert not pq.exists()
    assert not list(tmp_path.rglob("ozet.json"))


def test_yaz_atomik(tmp_path, monkeypatch):
    o = Onbellek(tmp_path, "demo", "k")
    o.yaz({"x": "eski"}, pd.DataFrame({"vaka_id": ["x"]}))

    def patla(*a, **k):
        raise RuntimeError("yazim ortasi")

    monkeypatch.setattr(onbellek.os, "replace", patla)
    with pytest.raises(RuntimeError):
        o.yaz({"x": "yeni"}, pd.DataFrame({"vaka_id": ["y", "z"]}))
    monkeypatch.undo()
    ozet, df = o.oku()
    assert ozet == {"x": "eski"} and list(df["vaka_id"]) == ["x"]


def test_kilit_ikinci_alamaz(tmp_path):
    a, b = Onbellek(tmp_path, "demo", "k"), Onbellek(tmp_path, "demo", "k")
    with a.kilit():
        with pytest.raises(KilitMesgul):
            with b.kilit():
                pass
    with b.kilit():
        pass
