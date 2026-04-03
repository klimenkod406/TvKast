# Digital Signage System

## Краткое описание
Система управления цифровыми табло: админ-панель, сервер API/WebSocket и веб-клиент для Smart TV.

## Установка «для всех» (Windows, без правки кода)

1. Установите **Node.js 18+** (https://nodejs.org/) и **PostgreSQL 14+** (https://www.postgresql.org/download/windows/), включите **PostgreSQL** в «Службах».
2. Запустите **`Install.cmd`** (двойной щелчок) и ответьте на вопросы мастера.
3. После появления файла **`INSTALL_OK`** запускайте **`Start.cmd`**.
4. Откройте в браузере: `http://localhost:3000/admin/login.html` (логин `admin`, пароль — тот, что задан при установке).

Лог установки: `%TEMP%\DigitalSignage-Setup.log`

Сборка `setup.exe`: откройте `setup.iss` в **Inno Setup** и скомпилируйте установщик.

## Быстрый старт (разработчик)
1. Скопируйте `.env.example` в `.env` или выполните `Install.cmd`
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
1. Собрать проект
2. Использовать `setup.iss` для создания `setup.exe`
3. Установить как Windows-сервис через `install-service.bat`

## Структура проекта
- `src` - сервер
- `public` - админ-панель и клиент экрана
- `media` - исходные и конвертированные медиа
- `database` - SQL инициализация
- `scripts` - утилиты

## Команды
- `npm run dev` - запуск сервера
- `npm start` - запуск сервера
- `npm run db:init` - инициализация БД
- `npm run password:generate -- myPassword` - генерация bcrypt-хэша

## Переменные окружения
- `PORT=3000`
- `DATABASE_URL=postgresql://...`
- `JWT_SECRET=...`
- `ADMIN_LOGIN=admin`
- `ADMIN_PASSWORD_HASH=...`
- `FFMPEG_PATH=ffmpeg`

## Контакты
Ответственный разработчик: platform-team@company.com
