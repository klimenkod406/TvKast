CREATE TABLE IF NOT EXISTS admins (
  id UUID PRIMARY KEY,
  login VARCHAR(120) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS media (
  id UUID PRIMARY KEY,
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  original_path TEXT NOT NULL,
  gif_path TEXT,
  file_size BIGINT NOT NULL,
  duration_seconds DOUBLE PRECISION,
  conversion_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  conversion_progress INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  converted_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS playlists (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS playlist_items (
  id UUID PRIMARY KEY,
  playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  "order" INTEGER NOT NULL DEFAULT 0,
  duration_seconds INTEGER NOT NULL DEFAULT 10
);

-- Группы экранов
CREATE TABLE IF NOT EXISTS screen_groups (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS screens (
  id UUID PRIMARY KEY,
  name VARCHAR(255),
  ip_address INET,
  group_id UUID REFERENCES screen_groups(id) ON DELETE SET NULL,
  playlist_id UUID REFERENCES playlists(id),
  -- Медиа по умолчанию: показывается если плейлист не назначен или пуст
  default_media_id UUID REFERENCES media(id) ON DELETE SET NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'waiting',
  last_heartbeat TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Сценарии: правила автоматического переключения плейлистов
CREATE TABLE IF NOT EXISTS scenarios (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  playlist_id UUID REFERENCES playlists(id) ON DELETE SET NULL,
  group_id UUID REFERENCES screen_groups(id) ON DELETE CASCADE,
  -- Расписание
  days_of_week VARCHAR(20),       -- "1,2,3,4,5" (1=Mon) или NULL = каждый день
  time_from TIME,                 -- Время начала
  time_to TIME,                   -- Время окончания
  date_from DATE,                 -- Дата начала действия (или NULL)
  date_to DATE,                   -- Дата окончания действия (или NULL)
  -- Состояние
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  priority INTEGER NOT NULL DEFAULT 0,  -- Приоритет (больше = важнее)
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pending_commands (
  id UUID PRIMARY KEY,
  screen_id UUID NOT NULL REFERENCES screens(id) ON DELETE CASCADE,
  command_type VARCHAR(50) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  executed_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS event_logs (
  id UUID PRIMARY KEY,
  screen_id UUID REFERENCES screens(id) ON DELETE SET NULL,
  event_type VARCHAR(64) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
