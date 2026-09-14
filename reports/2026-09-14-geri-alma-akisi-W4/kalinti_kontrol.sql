-- W4 kalıntı kontrolü — SALT OKUNUR: k4 sonrası DEMO temiz mi, trigger'lar açık mı?
\set ON_ERROR_STOP 1
BEGIN READ ONLY;
\echo '== k4 kalıntısı =='
SELECT (SELECT count(*) FROM public.degisim_log WHERE kaynak ->> 'istemci_etiketi' = 'k4-onarim-testi') AS k4_log,
       (SELECT count(*) FROM public.padoklar WHERE ad LIKE 'k4-%') AS k4_padok,
       (SELECT count(*) FROM public.hayvanlar WHERE id LIKE 'k4-%') AS k4_hayvan,
       (SELECT count(*) FROM public.tohumlama WHERE sperma LIKE 'k4-%') AS k4_tohum,
       (SELECT count(*) FROM public.dogum WHERE yavru_kupe LIKE 'k4-%') AS k4_dogum,
       (SELECT count(*) FROM public.grup_padok_eslem WHERE grup LIKE 'k4-G-%') AS k4_eslem,
       (SELECT count(*) FROM public.islem_log WHERE payload ->> 'k4onarim' IS NOT NULL) AS k4_islem,
       (SELECT count(*) FROM surum_gizli.l4_rehber_adimlari) AS jeton_toplam;
\echo '== trigger durumu (hepsi t olmalı) =='
SELECT c.relname, t.tgname, t.tgenabled <> 'D' AS acik
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 WHERE t.tgname IN ('trg_degisim_log','trg_islem_hayvanlar','trg_tohumlama_gebe_gorev',
                    'trg_islem_dogum','trg_vaccination_stok','trg_islem_tohumlama_insert')
   AND NOT t.tgisinternal
 ORDER BY c.relname, t.tgname;
\echo '== sahip şifresi var mı (k3 dengeleyicisi) =='
SELECT count(*) AS sifre FROM surum_gizli.sahip_sifresi;
ROLLBACK;
