const fs = require("fs");
const path = require("path");
const http = require("http");
const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const multer = require("multer");
const { v4: uuidv4 } = require("uuid");
const { Pool } = require("pg");
const { WebSocketServer } = require("ws");
const { spawn } = require("child_process");
require("dotenv").config();

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || "change-me";
const FFMPEG_PATH = process.env.FFMPEG_PATH || "ffmpeg";
const USE_VIDEO_IF_SUPPORTED = String(process.env.USE_VIDEO_IF_SUPPORTED || "false") === "true";

const ROOT = path.join(__dirname, "..");
const LOGS_DIR = path.join(ROOT, "logs");
fs.mkdirSync(LOGS_DIR, { recursive: true });

// ============================================================
// Файловое логирование
// ============================================================
const LOG_ACCESS  = path.join(LOGS_DIR, "access.log");
const LOG_AUTH    = path.join(LOGS_DIR, "auth.log");
const LOG_ERROR   = path.join(LOGS_DIR, "error.log");

function logFile(filePath, line) {
  const ts = new Date().toISOString();
  fs.appendFileSync(filePath, `[${ts}] ${line}\n`, "utf8");
}

function logAccess(method, url, ip, status, duration) {
  logFile(LOG_ACCESS, `${method} ${url} ${ip} ${status} ${duration}ms`);
}

function logAuth(action, login, success, detail) {
  logFile(LOG_AUTH, `${action} login=${login} ${success ? "OK" : "FAIL"} ${detail || ""}`);
}

function logError(ctx, err) {
  const msg = err instanceof Error ? err.stack : String(err);
  logFile(LOG_ERROR, `[${ctx}] ${msg}`);
}

// ============================================================
// Создание директорий
// ============================================================
const MEDIA_ROOT = path.join(ROOT, "media");
const ORIGINAL_DIR = path.join(MEDIA_ROOT, "original");
const CONVERTED_DIR = path.join(MEDIA_ROOT, "converted");
const METADATA_DIR = path.join(MEDIA_ROOT, "metadata");
for (const dir of [MEDIA_ROOT, ORIGINAL_DIR, CONVERTED_DIR, METADATA_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const app = express();

// Middleware: логирование HTTP-запросов
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    logAccess(req.method, req.originalUrl, req.ip, res.statusCode, Date.now() - start);
  });
  next();
});

app.use(cors());
app.use(express.json({ limit: "20mb" }));
app.use("/media", express.static(MEDIA_ROOT));
app.use("/admin", express.static(path.join(ROOT, "public")));

const upload = multer({
  dest: ORIGINAL_DIR,
  limits: { fileSize: 500 * 1024 * 1024 },
});

const socketsByScreenId = new Map();
const adminSockets = new Set();
const queue = [];
let conversionInProgress = false;

function signToken(admin) {
  return jwt.sign({ sub: admin.id, login: admin.login }, JWT_SECRET, { expiresIn: "12h" });
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || "";
  const [, token] = header.split(" ");
  if (!token) return res.status(401).json({ error: "Unauthorized" });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (err) {
    logError("AUTH_TOKEN", err);
    res.status(401).json({ error: "Invalid token" });
  }
}

function wsSend(ws, event, data) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify({ event, data }));
}

function broadcastAdmin(event, data) {
  for (const ws of adminSockets) wsSend(ws, event, data);
}

async function logEvent(screenId, eventType, message) {
  await pool.query(
    "INSERT INTO event_logs (id, screen_id, event_type, message) VALUES ($1, $2, $3, $4)",
    [uuidv4(), screenId || null, eventType, message]
  );
}

async function getPlaylistMedia(playlistId) {
  if (!playlistId) return [];
  const { rows } = await pool.query(
    `SELECT pi.id, pi."order", pi.duration_seconds, m.id AS media_id, m.original_name,
            m.mime_type, m.original_path, m.gif_path, m.conversion_status, m.duration_seconds AS media_duration
       FROM playlist_items pi
       JOIN media m ON m.id = pi.media_id
      WHERE pi.playlist_id = $1
      ORDER BY pi."order" ASC`,
    [playlistId]
  );
  return rows.map((item) => {
    const canUseVideo = USE_VIDEO_IF_SUPPORTED && item.conversion_status !== "completed";
    // Для GIF используем длительность из duration_seconds (плейлиста) или media_duration (из метаданных видео)
    const resolvedDuration = item.duration_seconds || item.media_duration || 10;
    return {
      id: item.media_id,
      name: item.original_name,
      duration: resolvedDuration,
      type: item.mime_type,
      src: canUseVideo ? item.original_path.replace(/\\/g, "/") : (item.gif_path || item.original_path).replace(/\\/g, "/"),
    };
  });
}

async function sendPlaylistToScreen(screenId, playlistId) {
  const mediaList = await getPlaylistMedia(playlistId);
  const commandId = uuidv4();
  const ws = socketsByScreenId.get(screenId);
  if (!ws) {
    await pool.query(
      "INSERT INTO pending_commands (id, screen_id, command_type, payload, status) VALUES ($1, $2, 'playlist_change', $3, 'pending')",
      [commandId, screenId, JSON.stringify({ playlistId, mediaList, commandId })]
    );
    return { queued: true, commandId };
  }
  wsSend(ws, "playlist-change", { playlistId, mediaList, commandId });
  await pool.query(
    "INSERT INTO pending_commands (id, screen_id, command_type, payload, status) VALUES ($1, $2, 'playlist_change', $3, 'pending')",
    [commandId, screenId, JSON.stringify({ playlistId, mediaList, commandId })]
  );
  return { queued: false, commandId };
}

function getVideoDuration(inputPath) {
  return new Promise((resolve, reject) => {
    const args = [
      "-v", "error",
      "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      inputPath,
    ];
    const ff = spawn(FFMPEG_PATH, args);
    let output = "";
    ff.stdout.on("data", (buf) => { output += String(buf); });
    ff.on("close", (code) => {
      if (code === 0) {
        const dur = parseFloat(output.trim());
        resolve(isNaN(dur) ? null : dur);
      } else {
        reject(new Error("ffprobe failed with code " + code));
      }
    });
    ff.on("error", reject);
  });
}

function convertToGif(inputPath, outputPath, duration, progressCb) {
  return new Promise((resolve, reject) => {
    const targetFps = duration && duration > 0 ? Math.min(15, Math.max(5, Math.ceil(300 / duration))) : 15;

    // Гарантируем существование директории вывода
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });

    const args = [
      "-nostdin",
      "-i", inputPath,
      "-vf", `fps=${targetFps},scale=1920:-1:flags=lanczos`,
      "-y",
      outputPath,
    ];

    logError("FFMPEG_ARGS", { cmd: FFMPEG_PATH, args });

    const ff = spawn(FFMPEG_PATH, args);
    let stderrBuf = "";

    ff.stderr.on("data", (buf) => {
      stderrBuf += String(buf);
      const line = String(buf);
      const match = line.match(/time=(\d+):(\d+):(\d+\.\d+)/);
      if (match && duration && duration > 0) {
        const [, hh, mm, ss] = match;
        const currentSeconds = Number(hh) * 3600 + Number(mm) * 60 + Number(ss);
        const percent = Math.min(99, Math.round((currentSeconds / duration) * 100));
        progressCb(percent);
      } else if (match) {
        const [, hh, mm, ss] = match;
        const seconds = Number(hh) * 3600 + Number(mm) * 60 + Number(ss);
        const percent = Math.max(1, Math.min(99, Math.floor(seconds / 6)));
        progressCb(percent);
      }
    });

    ff.on("close", (code) => {
      if (code === 0) resolve();
      else {
        const fullErr = `ffmpeg exited with code ${code}\nArgs: ${args.join(" ")}\nFull stderr:\n${stderrBuf}`;
        logError("CONVERSION_FAILED", fullErr);
        reject(new Error(fullErr));
      }
    });

    ff.on("error", (err) => reject(new Error(`ffmpeg spawn error: ${err.message}`)));
  });
}

async function processQueue() {
  if (conversionInProgress || queue.length === 0) return;
  conversionInProgress = true;
  const task = queue.shift();
  const outputPath = path.join(CONVERTED_DIR, `${task.id}.gif`);
  const relOutputPath = `/media/converted/${task.id}.gif`;

  try {
    await pool.query("UPDATE media SET conversion_status='processing', conversion_progress=0 WHERE id=$1", [task.id]);

    // Определяем длительность исходного видео
    let duration = task.duration || null;
    if (!duration) {
      try {
        duration = await getVideoDuration(task.originalAbsPath);
      } catch (durError) {
        logError("VIDEO_DURATION_QUEUE", durError);
      }
    }

    // Конвертируем в GIF
    await convertToGif(task.originalAbsPath, outputPath, duration, async (progress) => {
      await pool.query("UPDATE media SET conversion_progress=$1 WHERE id=$2", [progress, task.id]);
      broadcastAdmin("conversion-progress", { mediaId: task.id, progress });
    });

    // Сохраняем метаданные
    const metadataPath = path.join(METADATA_DIR, `${task.id}.json`);
    const metadata = {
      id: task.id,
      original_name: task.originalName,
      duration: duration,
      gif_path: relOutputPath,
      conversion_status: "completed",
      created_at: new Date().toISOString(),
      converted_at: new Date().toISOString(),
    };
    fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2), "utf8");

    // Обновляем запись в БД: сохраняем длительность
    await pool.query(
      "UPDATE media SET conversion_status='completed', conversion_progress=100, gif_path=$1, duration_seconds=$2, converted_at=NOW() WHERE id=$3",
      [relOutputPath, duration, task.id]
    );
    broadcastAdmin("conversion-completed", { mediaId: task.id, duration });
  } catch (error) {
    const errMsg = error instanceof Error ? (error.stack || error.message) : String(error);
    logError("CONVERSION", { taskId: task.id, error: errMsg });
    await pool.query(
      "UPDATE media SET conversion_status='failed', error_message=$1 WHERE id=$2",
      [errMsg.slice(0, 500), task.id]
    );
    broadcastAdmin("conversion-failed", { mediaId: task.id, error: errMsg.slice(0, 200) });
  } finally {
    conversionInProgress = false;
    processQueue();
  }
}

app.get("/", (_req, res) => {
  res.redirect("/admin/index.html");
});

app.get("/display/:screenId", (_req, res) => {
  res.sendFile(path.join(ROOT, "public", "display.html"));
});

app.post("/api/auth/login", async (req, res) => {
  const { login, password } = req.body || {};
  try {
    const { rows } = await pool.query("SELECT * FROM admins WHERE login = $1", [login]);
    const admin = rows[0];
    if (!admin) {
      logAuth("LOGIN", login || "unknown", false, "User not found");
      return res.status(401).json({ error: "Invalid credentials" });
    }
    const ok = bcrypt.compareSync(password || "", admin.password_hash);
    if (!ok) {
      logAuth("LOGIN", login, false, "Wrong password");
      return res.status(401).json({ error: "Invalid credentials" });
    }
    logAuth("LOGIN", login, true, "");
    res.json({ token: signToken(admin), mustChangePassword: admin.must_change_password });
  } catch (err) {
    logError("AUTH", err);
    res.status(500).json({ error: "Internal error" });
  }
});

app.get("/api/screens", authMiddleware, async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT s.id, s.name, host(s.ip_address) AS ip_address, s.group_id, g.name AS group_name,
            s.playlist_id, p.name AS playlist_name, s.status, s.last_heartbeat, s.created_at
       FROM screens s
       LEFT JOIN screen_groups g ON g.id = s.group_id
       LEFT JOIN playlists p ON p.id = s.playlist_id
      ORDER BY s.created_at DESC`
  );
  res.json(rows);
});

app.patch("/api/screens/:screenId/playlist", authMiddleware, async (req, res) => {
  const { screenId } = req.params;
  const { playlistId } = req.body || {};
  await pool.query("UPDATE screens SET playlist_id=$1, updated_at=NOW() WHERE id=$2", [playlistId, screenId]);
  const result = await sendPlaylistToScreen(screenId, playlistId);
  await logEvent(screenId, "playlist_change", `Playlist changed to ${playlistId}`);
  res.json({ ok: true, ...result });
});

app.patch("/api/screens/bulk-playlist", authMiddleware, async (req, res) => {
  const { screenIds, playlistId } = req.body || {};
  const ids = Array.isArray(screenIds) ? screenIds : [];
  for (const screenId of ids) {
    await pool.query("UPDATE screens SET playlist_id=$1, updated_at=NOW() WHERE id=$2", [playlistId, screenId]);
    await sendPlaylistToScreen(screenId, playlistId);
    await logEvent(screenId, "playlist_change", `Bulk playlist changed to ${playlistId}`);
  }
  res.json({ ok: true, affected: ids.length });
});

app.get("/api/display/:screenId/config", async (req, res) => {
  const { screenId } = req.params;
  const screenResult = await pool.query("SELECT playlist_id FROM screens WHERE id=$1", [screenId]);
  const screen = screenResult.rows[0];
  if (!screen) return res.status(404).json({ error: "Screen not found" });
  const mediaList = await getPlaylistMedia(screen.playlist_id);
  const pendingResult = await pool.query(
    "SELECT id, payload FROM pending_commands WHERE screen_id=$1 AND status='pending' ORDER BY created_at ASC",
    [screenId]
  );
  res.json({
    screenId,
    playlistId: screen.playlist_id,
    mediaList,
    pendingCommands: pendingResult.rows.map((r) => r.payload),
  });
});

app.get("/api/playlists", authMiddleware, async (_req, res) => {
  const { rows } = await pool.query("SELECT * FROM playlists ORDER BY created_at DESC");
  res.json(rows);
});

app.post("/api/playlists", authMiddleware, async (req, res) => {
  const { name, items = [] } = req.body || {};
  const id = uuidv4();
  await pool.query("INSERT INTO playlists (id, name) VALUES ($1, $2)", [id, name || "New playlist"]);
  for (let i = 0; i < items.length; i += 1) {
    const item = items[i];
    await pool.query(
      'INSERT INTO playlist_items (id, playlist_id, media_id, "order", duration_seconds) VALUES ($1, $2, $3, $4, $5)',
      [uuidv4(), id, item.mediaId, i, item.duration || 10]
    );
  }
  res.status(201).json({ id });
});

app.get("/api/media", authMiddleware, async (_req, res) => {
  const { rows } = await pool.query("SELECT * FROM media ORDER BY created_at DESC");
  res.json(rows);
});

app.post("/api/media/upload", authMiddleware, upload.single("file"), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: "File is required" });

  // Декодируем кириллицу из multipart (браузеры могут слать double-encoded UTF-8)
  let originalName = req.file.originalname;
  try {
    // Пробуем перекодировать если получились кракозябры (Latin-1 -> UTF-8)
    if (/[\x80-\xff]/.test(originalName) && !/^[\x20-\x7eа-яА-ЯёЁ]+$/.test(originalName)) {
      const fixed = Buffer.from(originalName, "latin1").toString("utf8");
      if (/[\u0400-\u04ff]/.test(fixed)) originalName = fixed;
    }
  } catch { /* оставляем как есть */ }

  const id = uuidv4();
  const ext = path.extname(originalName) || ".bin";
  const renamed = `${id}${ext.toLowerCase()}`;
  const absolutePath = path.join(ORIGINAL_DIR, renamed);
  fs.renameSync(req.file.path, absolutePath);
  const originalPath = `/media/original/${renamed}`;

  const mimeType = req.file.mimetype || "application/octet-stream";
  const isVideo = mimeType.startsWith("video/");
  const isImage = mimeType.startsWith("image/");

  // Определяем длительность только для видео
  let duration = null;
  if (isVideo) {
    try {
      duration = await getVideoDuration(absolutePath);
    } catch (durError) {
      logError("VIDEO_DURATION_UPLOAD", durError);
    }
  }

  // Для изображений — сразу готово, для видео — pending
  const status = isImage ? "completed" : (isVideo ? "pending" : "completed");
  const gifPath = isImage ? originalPath : null;
  const progress = isImage ? 100 : 0;

  await pool.query(
    `INSERT INTO media (id, original_name, mime_type, original_path, gif_path, file_size, duration_seconds, conversion_status, conversion_progress)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
    [id, originalName, mimeType, originalPath, gifPath, req.file.size, duration, status, progress]
  );

  // В очередь только видео
  if (isVideo) {
    queue.push({ id, originalAbsPath: absolutePath, originalName, duration });
    processQueue();
  }

  res.status(201).json({ id, status, duration });
});

app.delete("/api/media/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const result = await pool.query("SELECT original_path, gif_path FROM media WHERE id=$1", [id]);
  const media = result.rows[0];
  if (!media) return res.status(404).json({ error: "Not found" });

  const tryDelete = (rel) => {
    if (!rel) return;
    const abs = path.join(ROOT, rel.startsWith("/") ? rel.slice(1) : rel);
    if (fs.existsSync(abs)) fs.unlinkSync(abs);
  };
  tryDelete(media.original_path);
  tryDelete(media.gif_path);
  await pool.query("DELETE FROM media WHERE id=$1", [id]);
  res.json({ ok: true });
});

app.get("/api/media/:id/status", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { rows } = await pool.query("SELECT conversion_status FROM media WHERE id=$1", [id]);
  if (!rows[0]) return res.status(404).json({ error: "Not found" });
  res.json({ status: rows[0].conversion_status });
});

app.get("/api/media/:id/progress", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { rows } = await pool.query("SELECT conversion_progress FROM media WHERE id=$1", [id]);
  if (!rows[0]) return res.status(404).json({ error: "Not found" });
  res.json({ progress: rows[0].conversion_progress });
});

// ============================================================
// ПЛЕЙЛИСТЫ — CRUD
// ============================================================

// Удалить плейлист
app.delete("/api/playlists/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  await pool.query("DELETE FROM playlists WHERE id=$1", [id]);
  res.json({ ok: true });
});

// Переименовать плейлист
app.put("/api/playlists/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { name } = req.body || {};
  await pool.query("UPDATE playlists SET name=$1, updated_at=NOW() WHERE id=$2", [name, id]);
  res.json({ ok: true });
});

// Получить элементы плейлиста (с медиа-деталями)
app.get("/api/playlists/:id/items", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { rows } = await pool.query(
    `SELECT pi.id, pi."order", pi.duration_seconds,
            m.id AS media_id, m.original_name, m.mime_type, m.original_path,
            m.gif_path, m.conversion_status, m.file_size, m.duration_seconds AS media_duration
       FROM playlist_items pi
       JOIN media m ON m.id = pi.media_id
      WHERE pi.playlist_id = $1
      ORDER BY pi."order" ASC`,
    [id]
  );
  res.json(rows);
});

// Добавить медиа в плейлист
app.post("/api/playlists/:id/items", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { mediaId, duration } = req.body || {};
  if (!mediaId) return res.status(400).json({ error: "mediaId required" });

  // Определяем максимальный order
  const { rows: maxRows } = await pool.query(
    `SELECT COALESCE(MAX("order"), -1) AS max_order FROM playlist_items WHERE playlist_id=$1`, [id]
  );
  const nextOrder = maxRows[0].max_order + 1;

  await pool.query(
    'INSERT INTO playlist_items (id, playlist_id, media_id, "order", duration_seconds) VALUES ($1, $2, $3, $4, $5)',
    [uuidv4(), id, mediaId, nextOrder, duration || 10]
  );
  await pool.query("UPDATE playlists SET updated_at=NOW() WHERE id=$1", [id]);
  res.status(201).json({ ok: true });
});

// Удалить элемент из плейлиста
app.delete("/api/playlists/:pid/items/:itemId", authMiddleware, async (req, res) => {
  const { pid, itemId } = req.params;
  await pool.query("DELETE FROM playlist_items WHERE id=$1", [itemId]);
  await pool.query("UPDATE playlists SET updated_at=NOW() WHERE id=$1", [pid]);
  res.json({ ok: true });
});

// Переупорядочить элементы плейлиста
app.put("/api/playlists/:id/items/reorder", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { itemIds } = req.body || {}; // массив ID в нужном порядке
  if (!Array.isArray(itemIds)) return res.status(400).json({ error: "itemIds array required" });
  for (let i = 0; i < itemIds.length; i++) {
    await pool.query('UPDATE playlist_items SET "order"=$1 WHERE id=$2', [i, itemIds[i]]);
  }
  await pool.query("UPDATE playlists SET updated_at=NOW() WHERE id=$1", [id]);
  res.json({ ok: true });
});

// Обновить длительность элемента
app.put("/api/playlists/:pid/items/:itemId", authMiddleware, async (req, res) => {
  const { pid, itemId } = req.params;
  const { duration } = req.body || {};
  await pool.query("UPDATE playlist_items SET duration_seconds=$1 WHERE id=$2", [duration, itemId]);
  await pool.query("UPDATE playlists SET updated_at=NOW() WHERE id=$1", [pid]);
  res.json({ ok: true });
});

// ============================================================
// ГРУППЫ ЭКРАНОВ — CRUD
// ============================================================

app.get("/api/screens/groups", authMiddleware, async (_req, res) => {
  const { rows } = await pool.query("SELECT g.*, COUNT(s.id) AS screen_count FROM screen_groups g LEFT JOIN screens s ON s.group_id = g.id GROUP BY g.id ORDER BY g.name");
  res.json(rows);
});

app.post("/api/screens/groups", authMiddleware, async (req, res) => {
  const { name } = req.body || {};
  const id = uuidv4();
  await pool.query("INSERT INTO screen_groups (id, name) VALUES ($1, $2)", [id, name || "Новая группа"]);
  res.status(201).json({ id, name: name || "Новая группа" });
});

app.put("/api/screens/groups/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { name } = req.body || {};
  await pool.query("UPDATE screen_groups SET name=$1 WHERE id=$2", [name, id]);
  res.json({ ok: true });
});

app.delete("/api/screens/groups/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  await pool.query("DELETE FROM screen_groups WHERE id=$1", [id]);
  res.json({ ok: true });
});

// ============================================================
// ЭКРАН — обновление (группа, плейлист, имя)
// ============================================================

app.put("/api/screens/:screenId", authMiddleware, async (req, res) => {
  const { screenId } = req.params;
  const { name, groupId, playlistId } = req.body || {};

  const updates = [];
  const values = [];
  let idx = 1;

  if (name !== undefined)       { updates.push(`name=$${idx++}`); values.push(name); }
  if (groupId !== undefined)    { updates.push(`group_id=$${idx++}`); values.push(groupId || null); }
  if (playlistId !== undefined) { updates.push(`playlist_id=$${idx++}`); values.push(playlistId || null); }

  if (updates.length > 0) {
    updates.push("updated_at=NOW()");
    values.push(screenId);
    await pool.query(`UPDATE screens SET ${updates.join(", ")} WHERE id=$${idx}`, values);

    // Если плейлист изменён — отправить на экран
    if (playlistId !== undefined && playlistId) {
      await sendPlaylistToScreen(screenId, playlistId);
    }
  }

  res.json({ ok: true });
});

// ============================================================
// СЦЕНАРИИ — CRUD
// ============================================================

app.get("/api/scenarios", authMiddleware, async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT sc.*, p.name AS playlist_name, g.name AS group_name
       FROM scenarios sc
       LEFT JOIN playlists p ON p.id = sc.playlist_id
       LEFT JOIN screen_groups g ON g.id = sc.group_id
      ORDER BY sc.priority DESC, sc.name`
  );
  res.json(rows);
});

app.post("/api/scenarios", authMiddleware, async (req, res) => {
  const { name, playlistId, groupId, daysOfWeek, timeFrom, timeTo, dateFrom, dateTo, enabled, priority } = req.body || {};
  const id = uuidv4();
  await pool.query(
    `INSERT INTO scenarios (id, name, playlist_id, group_id, days_of_week, time_from, time_to, date_from, date_to, enabled, priority)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
    [id, name || "Сценарий", playlistId || null, groupId || null, daysOfWeek || null,
     timeFrom || null, timeTo || null, dateFrom || null, dateTo || null,
     enabled !== false, priority || 0]
  );
  res.status(201).json({ id });
});

app.put("/api/scenarios/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { name, playlistId, groupId, daysOfWeek, timeFrom, timeTo, dateFrom, dateTo, enabled, priority } = req.body || {};
  await pool.query(
    `UPDATE scenarios SET name=COALESCE($1, name), playlist_id=COALESCE($2, playlist_id),
                        group_id=COALESCE($3, group_id), days_of_week=COALESCE($4, days_of_week),
                        time_from=COALESCE($5, time_from), time_to=COALESCE($6, time_to),
                        date_from=COALESCE($7, date_from), date_to=COALESCE($8, date_to),
                        enabled=COALESCE($9, enabled), priority=COALESCE($10, priority),
                        updated_at=NOW()
     WHERE id=$11`,
    [name, playlistId, groupId, daysOfWeek, timeFrom, timeTo, dateFrom, dateTo, enabled, priority, id]
  );
  res.json({ ok: true });
});

app.delete("/api/scenarios/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  await pool.query("DELETE FROM scenarios WHERE id=$1", [id]);
  res.json({ ok: true });
});

// Проверить и применить сценарии
app.post("/api/scenarios/check", authMiddleware, async (_req, res) => {
  const applied = await checkAndApplyScenarios();
  res.json({ applied });
});

// ============================================================
// ПРОВЕРКА СЦЕНАРИЕВ (вызывается также по таймеру)
// ============================================================

async function checkAndApplyScenarios() {
  const now = new Date();
  const dayOfWeek = now.getDay(); // 0=Sun, 1=Mon...
  // Приведём к 1=Mon..7=Sun
  const isoDay = dayOfWeek === 0 ? 7 : dayOfWeek;
  const currentTime = now.toTimeString().slice(0, 8); // "HH:MM:SS"
  const currentDate = now.toISOString().slice(0, 10); // "YYYY-MM-DD"

  // Находим активные сценарии
  const { rows } = await pool.query(
    `SELECT sc.id, sc.playlist_id, sc.group_id, sc.days_of_week, sc.time_from, sc.time_to, sc.date_from, sc.date_to, sc.priority
       FROM scenarios sc
      WHERE sc.enabled = true
        AND (sc.days_of_week IS NULL OR sc.days_of_week LIKE '%' || $1 || '%')
        AND (sc.date_from IS NULL OR sc.date_from <= $2::date)
        AND (sc.date_to   IS NULL OR sc.date_to   >= $2::date)
      ORDER BY sc.priority DESC`,
    [String(isoDay), currentDate]
  );

  const applied = [];

  for (const sc of rows) {
    // Проверяем время
    if (sc.time_from && sc.time_to) {
      const tFrom = String(sc.time_from).slice(0, 8);
      const tTo = String(sc.time_to).slice(0, 8);
      if (currentTime < tFrom || currentTime > tTo) continue;
    }

    // Определяем экраны: по группе или все
    let screenIds = [];
    if (sc.group_id) {
      const { rows: screens } = await pool.query("SELECT id FROM screens WHERE group_id = $1", [sc.group_id]);
      screenIds = screens.map(s => s.id);
    } else {
      const { rows: screens } = await pool.query("SELECT id FROM screens");
      screenIds = screens.map(s => s.id);
    }

    for (const screenId of screenIds) {
      if (sc.playlist_id) {
        await pool.query("UPDATE screens SET playlist_id=$1, updated_at=NOW() WHERE id=$2", [sc.playlist_id, screenId]);
        await sendPlaylistToScreen(screenId, sc.playlist_id);
        applied.push({ screenId, playlistId: sc.playlist_id, scenarioId: sc.id });
      }
    }
  }

  return applied;
}

// Таймер проверки сценариев каждые 60 секунд
setInterval(async () => {
  try {
    const applied = await checkAndApplyScenarios();
    if (applied.length > 0) {
      console.log(`Scenarios applied: ${applied.length} screens updated`);
    }
  } catch (err) {
    logError("SCENARIO_CHECK", err);
  }
}, 60000);

// ============================================================
// HEARTBEAT
// ============================================================

app.post("/api/display/:screenId/heartbeat", async (req, res) => {
  const { screenId } = req.params;
  await pool.query("UPDATE screens SET status='online', last_heartbeat=NOW(), updated_at=NOW() WHERE id=$1", [screenId]);
  broadcastAdmin("screen-heartbeat", { screenId, at: new Date().toISOString() });
  res.json({ ok: true });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/ws" });

wss.on("connection", (ws, req) => {
  ws.on("message", async (raw) => {
    try {
      const msg = JSON.parse(String(raw));
      if (msg.event === "admin-subscribe") {
        adminSockets.add(ws);
        return;
      }
      if (msg.event === "register") {
        const { screenId } = msg.data || {};
        if (!screenId) return;
        const ip = req.socket.remoteAddress || null;
        socketsByScreenId.set(screenId, ws);
        ws.screenId = screenId;
        await pool.query(
          `INSERT INTO screens (id, status, ip_address, name)
           VALUES ($1, 'waiting', $2, $3)
           ON CONFLICT (id)
           DO UPDATE SET ip_address = EXCLUDED.ip_address, updated_at = NOW()`,
          [screenId, ip, `Screen-${String(screenId).slice(0, 6)}`]
        );
        broadcastAdmin("screen-registered", { screenId, ip, status: "waiting" });
        await logEvent(screenId, "register", "Screen registered");
        return;
      }
      if (msg.event === "heartbeat") {
        const { screenId } = msg.data || {};
        if (!screenId) return;
        await pool.query("UPDATE screens SET status='online', last_heartbeat=NOW(), updated_at=NOW() WHERE id=$1", [screenId]);
        broadcastAdmin("screen-heartbeat", { screenId, at: new Date().toISOString() });
        return;
      }
      if (msg.event === "ack") {
        const { commandId, status } = msg.data || {};
        if (!commandId) return;
        await pool.query("UPDATE pending_commands SET status=$1, executed_at=NOW() WHERE id=$2", [status || "executed", commandId]);
        broadcastAdmin("command-ack", { commandId, status: status || "executed" });
      }
    } catch (_error) {
      // ignore malformed events
    }
  });

  ws.on("close", async () => {
    adminSockets.delete(ws);
    if (ws.screenId) {
      socketsByScreenId.delete(ws.screenId);
      await pool.query("UPDATE screens SET status='offline', updated_at=NOW() WHERE id=$1", [ws.screenId]);
      broadcastAdmin("screen-offline", { screenId: ws.screenId });
      await logEvent(ws.screenId, "disconnect", "Screen disconnected");
    }
  });
});

setInterval(async () => {
  await pool.query(
    "UPDATE screens SET status='offline' WHERE status='online' AND (last_heartbeat IS NULL OR last_heartbeat < NOW() - INTERVAL '60 seconds')"
  );
}, 10000);

server.listen(PORT, () => {
  console.log(`Digital Signage server started on http://localhost:${PORT}`);
});
