#!/usr/bin/env python3
"""P5 ek bölüm — Y (13:52 ara yedek) içinde bugün penceresinin sayımı.

Pencere: 2026-09-15 00:00 – 13:52 TSI (sahibin bugün öğlene kadarki değişiklikleri)
       = UTC 2026-09-14T21:00Z – 2026-09-15T10:52Z
Damga kabulü: UTC (kanıt: Adım A raporu "en son yazım stok_hareket 09:12 (UTC)";
UTC varsayım denetimi pencere-dışı bugün sayacıyla yapılır).

Her tablo için tek zaman kolonu seçimi (data_type timestamp/date olanlar arasında):
updated_at > created_at > tarih > kayit_zamani > kayit_tarihi > timestamp.
Yalnız SAYIM çıkar: tablo × TSI saat kovası + islem_log "tip" dağılımı. Değer yok.
"""
import json, re, pathlib, collections

HERE = pathlib.Path(__file__).resolve().parent
Y = pathlib.Path("/home/melik/tmp/agents/prod-yedek-2026-09-15")

# TSI = UTC+3
def tsi_hour(iso):
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})", iso or "")
    if not m:
        return None
    y, mo, d, h, mi = map(int, m.groups())
    import datetime as dt
    u = dt.datetime(y, mo, d, h, mi)
    t = u + dt.timedelta(hours=3)
    return t.strftime("%Y-%m-%d %H:00 TSI")

lo = "2026-09-15 00:00 TSI"
hi = "2026-09-15 13:52 TSI"

cols = json.loads((Y / "columns.json").read_text())
PREF = ["updated_at", "created_at", "tarih", "kayit_zamani", "kayit_tarihi", "timestamp"]
tcol = {}
for r in cols:
    if r["table_schema"] != "public" or not str(r["data_type"]).startswith(("timestamp", "date")):
        continue
    t, c = r["table_name"], r["column_name"]
    cur = tcol.get(t)
    if cur is None or (c in PREF and (cur not in PREF or PREF.index(c) < PREF.index(cur))):
        tcol[t] = c

out, islem_tip, uyari = {}, collections.Counter(), []
for tf in sorted(Y.glob("table_*.json")):
    tbl = tf.stem.removeprefix("table_")
    c = tcol.get(tbl)
    if not c:
        continue
    rows = json.loads(tf.read_text())["data"]
    if not rows:
        continue
    if c not in rows[0]:
        continue
    cnt, dis, after = collections.Counter(), collections.Counter(), 0
    for r in rows:
        k = tsi_hour(str(r.get(c) or ""))
        if not k:
            continue
        if lo <= k <= hi:
            cnt[k] += 1
            if tbl == "islem_log":
                islem_tip[str(r.get("tip") or "?")] += 1
        elif k >= "2026-09-15 13:00 TSI":
            # pencere üstü bugün kaydı: UTC varsayımı ihlali adayı (Y 13:52 TSI'da alındı)
            after += 1
    if cnt or after:
        out[tbl] = {"kolon": c, "pencere_toplam": sum(cnt.values()),
                    "saat": dict(sorted(cnt.items())), "pencere_ustu_bugun": after}

tip_out = {"pencere_toplam": sum(islem_tip.values()),
           "tip": dict(sorted(islem_tip.items(), key=lambda x: -x[1]))}
(HERE / "today_counts.json").write_text(json.dumps(
    {"pencere": f"{lo} – {hi} (damgalar UTC kabul, TSI'ya çevrildi; TSI=UTC+3)",
     "tables": out, "islem_log_tip": tip_out}, ensure_ascii=False, indent=1))

print(f"pencere: {lo} – {hi}")
for t, r in sorted(out.items()):
    print(f"  {t} ({r['kolon']}): {r['pencere_toplam']} satır; {r['saat']}"
          + (f" PENCERE-ÜSTÜ={r['pencere_ustu_bugun']}" if r["pencere_ustu_bugun"] else ""))
print("islem_log tip:", dict(tip_out["tip"]))
