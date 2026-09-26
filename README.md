# TvKast — Digital Signage System

A complete digital-signage stack: an admin panel, an API/WebSocket
server, and a Smart-TV-friendly web client. Schedules, playlists and
media are managed from the browser and pushed to displays in real
time.

## What you get

- **Server** — Express + WebSocket on Node.js, single `src/server.js`
  entry point.
- **Admin panel** — login, screens dashboard, playlists, media
  uploads, scenarios (schedule), settings.
- **Display client** — `public/display.html`, the page that runs on
  the Smart TV and shows scheduled content.
- **Installer** — `Install.ps1`, a guided PowerShell wizard with a
  colored CLI, masked password input, automatic download of `ffmpeg`
  and `NSSM`.
- **Inno Setup script** — `setup.iss` for producing a Windows
  installer (`setup.exe`).

## Components

```
┌────────────────────────────────────────────┐
│  Admin panel (public/admin/*.html)         │
└─────────────────┬──────────────────────────┘
                  │ HTTPS / WebSocket
┌─────────────────▼──────────────────────────┐
│  Server (Express + WebSocket)              │   Port 3000
│  src/server.js                             │
└─────────────────┬──────────────────────────┘
                  │ pg
┌─────────────────▼──────────────────────────┐
│  PostgreSQL (9 tables, init.sql)           │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│  Display client (public/display.html)      │
│  Runs in full-screen on a Smart TV / kiosk  │
└────────────────────────────────────────────┘
```

## Features

- **Screens** — register displays, see status and current content.
- **Playlists** — order media items, set durations.
- **Scenarios** — time-based scheduling (weekday, date, time-of-day).
- **Media** — upload video / images, transcode via `ffmpeg` when
  needed.
- **Settings** — runtime configuration from the admin UI.
- **Auth** — bcrypt password hashing, JWT sessions, role-based access.
- **i18n** — multi-language UI strings (`public/i18n.js`).

## Requirements

- **Node.js 18+**
- **PostgreSQL 14+**
- **ffmpeg 5.0+** (the installer can download it automatically)
- **Windows** is the primary target; the installer is PowerShell.
  Linux/macOS work with manual setup.

## Installation (Windows, no code changes)

1. Install **Node.js 18+** and **PostgreSQL 14+**. Make sure the
   PostgreSQL service is running.
2. Run **`Install.ps1`** — right-click → "Run with PowerShell", or
   `powershell -File Install.ps1` from a console.
3. Follow the wizard. It sets up the database, creates tables, seeds
   the admin account and (optionally) registers a Windows service
   with NSSM.
4. Open `http://localhost:3000/admin/login.html` in your browser.
   Default login: `admin` (the password you chose during install).

Install log: `%TEMP%\DigitalSignage-Setup.log`.

## Quick start (developer)

```bash
git clone https://github.com/klimenkod406/TvKast.git
cd TvKast
cp .env.example .env       # then edit DATABASE_URL, JWT_SECRET, ...
npm install
npm run db:init
npm run dev
```

Then open `http://localhost:3000/admin/login.html`.

## Project layout

```
TvKast/
├── src/
│   └── server.js          # Express + WebSocket, single entry point
├── public/                # Admin UI + display client
│   ├── index.html         # root redirect
│   ├── login.html         # authentication
│   ├── screens.html       # screen management + monitoring
│   ├── playlists.html     # playlist editor
│   ├── media.html         # media upload
│   ├── scenarios.html     # scheduling
│   ├── settings.html      # system settings
│   ├── display.html       # Smart TV client
│   ├── styles.css         # shared styles
│   └── i18n.js            # UI translations
├── database/
│   ├── init.sql           # schema (9 tables)
│   └── migrate_default_media.sql
├── scripts/               # DB init / ensure / setup helpers
├── Install.ps1            # guided installer (Windows)
├── setup.iss              # Inno Setup project → setup.exe
├── download-ffmpeg.ps1    # ffmpeg downloader
├── diagnose.ps1           # diagnostic helper
└── SECURITY.md            # security notes
```

## Security

See `SECURITY.md` for details. Highlights:

- bcrypt password hashing (cost factor 12).
- JWT sessions with a configurable secret.
- Role-based access for admin endpoints.
- Rate limiting on authentication routes.
- Database connection URL stored in `.env` only — never committed.

## License

MIT — see `LICENSE`.