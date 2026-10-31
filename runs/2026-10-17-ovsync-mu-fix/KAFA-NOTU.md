## Önceden cevaplanmış kararlar
- Ruling C: _vaka_ovsync_mu log kolu yalnız şablon protokol_ailesi=OVSYNC + iptal=false; :MANUEL sayılmaz; JS _hastalikKabulMu aynı kural
- Aktif iş artık doğum/küpe + görev-protokol fix: runs/2026-10-30-some-fixes/, goal G-20261030-DOGUM-KUPE-FIX ve G-20261030-PROTOKOL-ETKEN (DONE); ovsync-mu kapalı
- Ruling: GT audit 83 eski fark t8'i bloke etmez (apply öncesi/sonrası birebir aynı); ayrı GT senkron kalemi

## Sahibin cümleleri (birebir)
- Bu işte Muse yok, yalnız Anthropic. Ölü küpesi her yolda serbest, aynı anne dahil. UI'dan yalnız aktif hayvan düzenlenir, çıkmış aktiflerle aynı listede görünmez
- Sahip onayları verildi: 20261031000001 prod apply ve JS merge+push

## Açık kalemler
- v_gorev_log_sync kapalı log son-300 penceresi: JS log kolu false negatif riski (düşük, kapsam dışı)
- GT tam senkron: ground-truth-audit 83 fark (kapanış koşulu audit PASS)
- F4 ayrı iş: dismiss toplu iptal+süresiz, _gorev_dinle tarih alt sınırı. Bakiye: F3, buzagi_id NULL backfill, eski hayvan_ekle COUNT+1

## Nerede kaldım
- Prod tamam: 20261030000001, 20261030100001, 20261031000001 (t5, t8; yedekler ~/yedek/prod-yedek-2026-10-31-*)
- MERGED a0b2327; sıradaki aday işler board: .ss/some-fixes-BOARD.md

## Quiz
