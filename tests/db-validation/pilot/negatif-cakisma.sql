-- Pilot-negatif-2: sözdizimi GEÇERLİ ama mevcut tabloyla çakışır.
-- Beklenen: db-validate.sh FAIL (exit 1) — Faz C1 apply "already exists".
CREATE TABLE public.hayvanlar (
    id bigint PRIMARY KEY,
    kupe_no text
);
