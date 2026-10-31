"""DB katmani: env'den DSN, psycopg baglantisi ve Depo uygulamasi (spec 7.1). DSN hicbir mesaja girmez."""
from __future__ import annotations

import stat
from pathlib import Path
from typing import Protocol

import pandas as pd
import psycopg
from psycopg.types.json import Jsonb

KOLONLAR = ["vaka_id", "hastalik", "protokol_etiket", "baslangic", "sonuc", "olay_tarihi"]


def dsn_oku(profil: str) -> str:
    yol = Path.home() / ".config" / "stat-motor" / f"{profil}.env"
    if stat.S_IMODE(yol.stat().st_mode) & 0o077:
        raise PermissionError("env dosyası 600 olmalı")
    for satir in yol.read_text().splitlines():
        anahtar, _, deger = satir.partition("=")
        if anahtar.strip() == "STAT_MOTOR_DSN":
            return deger.strip().strip("'\"")
    raise KeyError("STAT_MOTOR_DSN env dosyasında yok")


def baglan(profil: str) -> psycopg.Connection:
    dsn = dsn_oku(profil)
    try:
        return psycopg.connect(dsn)
    except psycopg.Error as e:
        raise RuntimeError(f"bağlantı kurulamadı: {type(e).__name__}") from None


class Depo(Protocol):
    def ozet(self) -> dict[str, str]: ...
    def satirlar(self, ids: list[str]) -> pd.DataFrame: ...
    def kosum_ac(self) -> int: ...
    def kosum_kapat(self, id: int, durum: str, mesaj: str | None, degisen: dict) -> None: ...
    def yaz(self, olcum: str, zarflar: dict[str, dict], girdi_ozeti: str, motor_surum: str) -> None: ...
    def commit(self) -> None: ...
    def rollback(self) -> None: ...


class PgDepo:
    """yaz() transaction'i acik birakir (iki olcum tek transaction); commit()/rollback() kosum.py cagirir."""

    def __init__(self, conn: psycopg.Connection, surum: str):
        self.conn, self.surum = conn, surum

    def ozet(self) -> dict[str, str]:
        with self.conn.cursor() as c:
            c.execute("select vaka_id::text, hash from stat_ayikla_tedavi_vaka_ozet()")
            sonuc = dict(c.fetchall())
        self.conn.commit()
        return sonuc

    def satirlar(self, ids: list[str]) -> pd.DataFrame:
        with self.conn.cursor() as c:
            c.execute("select vaka_id::text, hastalik, protokol_etiket, baslangic, sonuc, olay_tarihi "
                      "from stat_ayikla_tedavi_vaka(%s::uuid[])", (ids,))
            df = pd.DataFrame(c.fetchall(), columns=KOLONLAR)
        self.conn.commit()
        return df

    def kosum_ac(self) -> int:
        with self.conn.cursor() as c:
            c.execute("insert into stat_motor_kosum (surum) values (%s) returning id", (self.surum,))
            (id,) = c.fetchone()
        self.conn.commit()
        return id

    def kosum_kapat(self, id: int, durum: str, mesaj: str | None, degisen: dict) -> None:
        with self.conn.cursor() as c:
            c.execute("update stat_motor_kosum set durum=%s, mesaj=%s, degisen_kaynaklar=%s, "
                      "bitis_at=now() where id=%s", (durum, mesaj, Jsonb(degisen), id))
        self.conn.commit()

    def yaz(self, olcum: str, zarflar: dict[str, dict], girdi_ozeti: str, motor_surum: str) -> None:
        with self.conn.cursor() as c:
            c.execute("delete from stat_analiz_sonuc where olcum=%s and anahtar->>'hastalik' <> all(%s::text[])",
                      (olcum, list(zarflar)))
            for hastalik, zarf in zarflar.items():
                c.execute(
                    "insert into stat_analiz_sonuc (olcum, anahtar, sonuc, girdi_ozeti, motor_surum) "
                    "values (%s, %s, %s, %s, %s) "
                    "on conflict (farm_id, olcum, anahtar) do update set sonuc=excluded.sonuc, "
                    "girdi_ozeti=excluded.girdi_ozeti, motor_surum=excluded.motor_surum, hesap_at=now()",
                    (olcum, Jsonb({"hastalik": hastalik}), Jsonb(zarf), girdi_ozeti, motor_surum))

    def commit(self) -> None:
        self.conn.commit()

    def rollback(self) -> None:
        self.conn.rollback()
