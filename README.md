# Digital Signage System

## Краткое описание
Система управления цифровыми табло: админ-панель, сервер API/WebSocket и веб-клиент для Smart TV.

## Установка «для всех» (Windows, без правки кода)

1. Установите **Node.js 18+** (https://nodejs.org/) и **PostgreSQL 14+** (https://www.postgresql.org/download/windows/), включите **PostgreSQL** в «Службах».
2. Запустите **`Install.ps1`** (правый клик → «Выполнить в PowerShell» или из консоли: `powershell -File Install.ps1`).
3. Следуйте подсказкам мастера — цветной CLI с интерактивным меню и маской пароля.
4. После установки сервер запустится автоматически (или через ярлык на рабочем столе).
5. Откройте в браузере: `http://localhost:3000/admin/login.html` (логин `admin`, пароль — тот, что задан при установке).

Лог установки: `%TEMP%\DigitalSignage-Setup.log`

### Файлы установщика

| Файл | Описание |
|------|----------|
| `Install.ps1` | **Единый CLI-установщик** — цветной вывод, меню, маска пароля, автоустановка NSSM и ffmpeg |
| `setup.iss` | Скрипт Inno Setup для создания `setup.exe` (компилируется в `installer-output/`) |
| `download-ffmpeg.ps1` | Скрипт загрузки ffmpeg (вызывается автоматически установщиком) |

## Быстрый старт (разработчик)
1. Скопируйте `.env.example` в `.env` или выполните `Install.ps1`
2. `npm install`
3. При необходимости укажите `DATABASE_URL` в `.env`
4. `npm run db:init`
5. `npm run dev`
6. Открыть `http://localhost:3000/admin/login.html`

## Требования
- Node.js >= 18.x
- PostgreSQL >= 14
- ffmpeg >= 5.0

## Установка (Production)
1. Запустить `Install.ps1` — установщик настроит БД, создаст таблицы и учётную запись
2. При наличии прав администратора — сервер зарегистрируется как Windows-сервис (NSSM)
3. Без прав — ярлык на рабочем столе запустит сервер вручную

## Структура проекта
```
TvKast/
├── src/                  # Сервер (Express + WebSocket)
│   └── server.js         # Единый файл сервера (~1030 строк)
├── public/               # Админ-панель и клиент экрана
│   ├── index.html        # Главная (редирект)
│   ├── login.html        # Авторизация
│   ├── screens.html      # Управление экранами и мониторинг
│   ├── playlists.html    # Управление плейлистами
│   ├── media.html        # Загрузка медиа
│   ├── scenarios.html    # Сценарии (расписание)
│   ├── settings.html     # Настройки
│   ├── display.html      # Клиент для Smart TV
│   ├── styles.css        # Стили (Kastamonu brand)
│   └── i18n.js           # Интернационализация
├── database/
│   ├── init.sql          # Схема БД (9 таблиц)
│   └── migrate_default_media.sql
├── scripts/
│   ├── init-db.js        # Инициализация БД
│   ├── ensure-db.js      # Проверка/создание БД и пользователя
│   ├── generate-password.js  # Генерация bcrypt-хэша
│   └── set-env-value.js  # Утилита записи в .env
├── media/                # Медиафайлы (создаётся при установке)
│   ├── original/         # Исходные файлы
│   ├── converted/        # GIF-конвертации
│   └── metadata/         # JSON-метаданные
├── logs/                 # Логи (создаётся при установке)
│   ├── access.log
│   ├── auth.log
│   └── error.log
├── Install.ps1           # CLI-установщик
└── .env.example          # Шаблон переменных окружения
```

## Команды
- `npm run dev` — запуск сервера (разработка)
- `npm start` — запуск сервера (production)
- `npm run db:init` — инициализация БД (создание таблиц и admin)
- `npm run db:ensure` — проверка/создание БД и пользователя PostgreSQL
- `npm run password:generate -- myPassword` — генерация bcrypt-хэша

## API эндпоинты

### Авторизация
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `POST` | `/api/auth/login` | Вход администратора (JWT) |

### Экраны
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `GET` | `/api/screens` | Список всех экранов |
| `PUT` | `/api/screens/:screenId` | Обновление экрана (имя, группа, плейлист, defaultMedia) |
| `DELETE` | `/api/screens/:screenId` | Удаление экрана |
| `PATCH` | `/api/screens/:screenId/playlist` | Сменить плейлист экрана |
| `PATCH` | `/api/screens/bulk-playlist` | Сменить плейлист группе экранов |
| `PATCH` | `/api/screens/group-playlist` | Сменить плейлист группе по ID |
| `GET` | `/api/screens/groups` | Список групп экранов |
| `POST` | `/api/screens/groups` | Создать группу |
| `PUT` | `/api/screens/groups/:id` | Переименовать группу |
| `DELETE` | `/api/screens/groups/:id` | Удалить группу |

### Плейлисты
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `GET` | `/api/playlists` | Список плейлистов |
| `POST` | `/api/playlists` | Создать плейлист |
| `PUT` | `/api/playlists/:id` | Переименовать плейлист |
| `DELETE` | `/api/playlists/:id` | Удалить плейлист |
| `GET` | `/api/playlists/:id/items` | Элементы плейлиста |
| `POST` | `/api/playlists/:id/items` | Добавить медиа в плейлист |
| `PUT` | `/api/playlists/:id/items/reorder` | Переупорядочить элементы |
| `PUT` | `/api/playlists/:pid/items/:itemId` | Обновить длительность элемента |
| `DELETE` | `/api/playlists/:pid/items/:itemId` | Удалить элемент |

### Медиа
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `GET` | `/api/media` | Список медиа |
| `POST` | `/api/media/upload` | Загрузка медиа (видео→GIF) |
| `DELETE` | `/api/media/:id` | Удаление медиа |
| `GET` | `/api/media/:id/status` | Статус конвертации |
| `GET` | `/api/media/:id/progress` | Прогресс конвертации |

### Сценарии
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `GET` | `/api/scenarios` | Список сценариев |
| `POST` | `/api/scenarios` | Создать сценарий |
| `PUT` | `/api/scenarios/:id` | Обновить сценарий |
| `DELETE` | `/api/scenarios/:id` | Удалить сценарий |
| `POST` | `/api/scenarios/check` | Принудительная проверка сценариев |

### Настройки
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `GET` | `/api/settings` | Получить настройки |
| `PUT` | `/api/settings` | Сохранить настройки |

### Дисплей (Smart TV)
| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| `GET` | `/display/:screenId` | Страница дисплея |
| `GET` | `/api/display/:screenId/config` | Конфигурация экрана (плейлист + pending-команды) |
| `POST` | `/api/display/:screenId/heartbeat` | Heartbeat от ТВ |

### WebSocket (`/ws`)
| Событие | Направление | Описание |
|---------|-------------|----------|
| `register` | ТВ → Сервер | Регистрация экрана |
| `heartbeat` | ТВ → Сервер | Сигнал активности |
| `ack` | ТВ → Сервер | Подтверждение команды |
| `admin-subscribe` | Админ → Сервер | Подписка на обновления |
| `playlist-change` | Сервер → ТВ | Команда смены плейлиста |
| `screen-heartbeat` | Сервер → Админ | Обновление heartbeat |
| `screen-registered` | Сервер → Админ | Новый экран |
| `screen-offline` | Сервер → Админ | Экран отключился |
| `conversion-progress` | Сервер → Админ | Прогресс GIF |
| `conversion-completed` | Сервер → Админ | Конвертация завершена |
| `conversion-failed` | Сервер → Админ | Ошибка конвертации |
| `command-ack` | Сервер → Админ | Подтверждение команды |

## Переменные окружения
| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `PORT` | Порт сервера | `3000` |
| `DATABASE_URL` | Строка подключения к PostgreSQL | `postgresql://digitalsignage:digitalsignage@localhost:5432/digitalsignage_db` |
| `JWT_SECRET` | Секретный ключ JWT | `change-me` |
| `ADMIN_LOGIN` | Логин администратора | `admin` |
| `ADMIN_PASSWORD_HASH` | bcrypt-хэш пароля | генерируется при установке |
| `FFMPEG_PATH` | Путь к ffmpeg | `ffmpeg` |
| `USE_VIDEO_IF_SUPPORTED` | Использовать видео вместо GIF (если ТВ поддерживает) | `false` |

## Схема базы данных

| Таблица | Описание |
|---------|----------|
| `admins` | Учётные записи администраторов |
| `media` | Медиафайлы (оригиналы + GIF) |
| `playlists` | Плейлисты |
| `playlist_items` | Элементы плейлистов (связь media ↔ playlists) |
| `screen_groups` | Группы экранов |
| `screens` | Экраны (Smart TV) |
| `scenarios` | Сценарии (расписание переключения плейлистов) |
| `pending_commands` | Отложенные команды для офлайн-экранов |
| `event_logs` | Журнал событий экранов |

## Контакты
Ответственный разработчик: platform-team@company.com
