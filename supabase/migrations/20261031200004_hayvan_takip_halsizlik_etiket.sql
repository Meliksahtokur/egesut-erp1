-- Migration: Hayvan Takip sebep etiketine HALSIZLIK
-- Tarih: 2026-10-31. Kaynak: sahip kararı, domain-rules §20.2. Önceki migration: 20261031200002.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
-- Tek fark: 200002'deki CASE'e HALSIZLIK satırı. Öznitelik ve ACL 200002 ile aynı.
-- ROLLBACK: 200002'deki CASE gövdesi CREATE OR REPLACE ile yeniden koşulur. Var olan görev açıklaması değişmez.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public._hayvan_takip_sebep_etiket(p_kod text)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_kod
    WHEN 'TOPALLIK' THEN 'Topallık'
    WHEN 'SUT_DUSUSU' THEN 'Süt düşüşü'
    WHEN 'ZAYIFLAMA' THEN 'Zayıflama'
    WHEN 'ISTAHSIZLIK' THEN 'İştahsızlık'
    WHEN 'HALSIZLIK' THEN 'Halsizlik'
    WHEN 'DIGER' THEN 'Diğer'
    ELSE p_kod
  END;
$function$;

REVOKE ALL ON FUNCTION public._hayvan_takip_sebep_etiket(text) FROM PUBLIC, anon, authenticated, service_role;
