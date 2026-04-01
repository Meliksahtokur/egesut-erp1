-- Migration: UI Telemetry Logger
-- Tarih: 2026-04-01
-- Açıklama: Test sırasında kullanıcı hareketleri ve UI hatalarını loglar

-- Tablo oluştur
create table if not exists public.ui_logs (
  id bigserial primary key,
  level text not null,        -- 'error' | 'warn' | 'action' | 'info'
  message text not null,
  source text,                -- dosya:satır (hata için)
  payload jsonb,              -- ek veri (form değerleri, tıklanan element vb.)
  session_id text,            -- test session'ı ayırt etmek için
  created_at timestamptz default now()
);

-- Index: session_id ve created_at ile hızlı sorgu
create index if not exists idx_ui_logs_session on public.ui_logs(session_id, created_at desc);

-- RLS aktif et
alter table public.ui_logs enable row level security;

-- Anon kullanıcı insert ve select yapabilir (test için)
create policy "anon insert" on public.ui_logs for insert to anon with check (true);
create policy "anon select" on public.ui_logs for select to anon using (true);
