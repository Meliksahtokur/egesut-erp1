-- drugs tablosuna eksik kolonları ekle + standart ilaçları seed et
ALTER TABLE public.drugs ADD COLUMN IF NOT EXISTS stock_item_id text REFERENCES public.stok(id) ON DELETE SET NULL;
ALTER TABLE public.drugs ADD COLUMN IF NOT EXISTS default_unit text;
ALTER TABLE public.drugs ADD COLUMN IF NOT EXISTS default_route text;

COMMENT ON COLUMN public.drugs.stock_item_id IS 'stok.id FK — NULL ise stok düşümü yapılmaz';
COMMENT ON COLUMN public.drugs.default_route IS 'IM | IV | SC | PO | Topikal | Intrauterin';

INSERT INTO drugs (name, default_unit, default_route) VALUES
  ('Makrovil', 'ml', 'IM'),
  ('Enrolen', 'ml', 'IM'),
  ('Florkem', 'ml', 'IM'),
  ('Penicilin', 'ml', 'IM'),
  ('Oksitetrasiklin', 'ml', 'IM'),
  ('Meloksikam', 'ml', 'IV'),
  ('Flunixin', 'ml', 'IV'),
  ('Deksametazon', 'ml', 'IM'),
  ('Kalsiyum Boroglukonat', 'ml', 'IV'),
  ('B12 Vitamini', 'ml', 'IM'),
  ('AD3E Vitamini', 'ml', 'IM'),
  ('Albendazol', 'ml', 'PO'),
  ('İvermektin', 'ml', 'SC')
ON CONFLICT (name) DO NOTHING;

NOTIFY pgrst, 'reload schema';
