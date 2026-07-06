-- H-14 fix: gorev_guncelle audit izi eksikti (islem_log INSERT yoktu).
-- Mevcut gorev_log UPDATE mantığı AYNEN korunuyor, sadece islem_log yazımı ekleniyor.
-- Önceki davranış: js/forms.js kaydetTaskEdit() UPDATE sonrası write('islem_log', {...}) çağırıyordu
-- ancak INSERT islem_tipi/islem_detay/kullanici/kaynak kolonlarını kullanıyordu -- gerçek şemada
-- bu kolonlar YOK (gerçek: tip, snapshot, kullanici_notu, durum, ref_id, ref_tablo). tip ve snapshot
-- NOT NULL olduğu için INSERT her seferinde 400/constraint hatası alıyor ve .catch(()=>{}) sessizce
-- yutuyordu. Yani gorev-duzenleme audit log'u HİÇ yazılmıyordu.
-- Bu fix: audit'i RPC içine taşı (doğru kolon adları), forms.js'deki hatalı write() çağrısı silinecek.
CREATE OR REPLACE FUNCTION public.gorev_guncelle(p_id text, p_aciklama text DEFAULT NULL::text, p_hedef_tarih text DEFAULT NULL::text, p_gorev_tipi text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.gorev_log
  SET
    aciklama    = COALESCE(p_aciklama,    aciklama),
    hedef_tarih = COALESCE(p_hedef_tarih::date, hedef_tarih),
    gorev_tipi  = COALESCE(p_gorev_tipi,  gorev_tipi)
  WHERE id = p_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu, durum) VALUES ('GOREV_GUNCELLE', (SELECT hayvan_id::text FROM public.gorev_log WHERE id = p_id::uuid), p_id, 'gorev_log', jsonb_build_object('guncellenen', jsonb_build_object('aciklama',p_aciklama,'hedef_tarih',p_hedef_tarih,'gorev_tipi',p_gorev_tipi)), format('Gorev guncellendi -- id=%s', p_id), 'aktif');
  RETURN jsonb_build_object('ok', true);
END;
$function$;
