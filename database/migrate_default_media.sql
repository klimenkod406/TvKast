-- Миграция: добавление default_media_id в screens
ALTER TABLE screens ADD COLUMN IF NOT EXISTS default_media_id UUID REFERENCES media(id) ON DELETE SET NULL;
