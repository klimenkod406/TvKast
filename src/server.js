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
  } catch {
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
    // Рассчитываем FPS так, чтобы GIF имел ту же длительность, что и исходное видео
    // Цель: максимум 15 FPS, но при этом общая длительность GIF = duration
    // Для длительности > 10 секунд: fps=15, для коротких видео: подбираем
    const targetFps = duration && duration > 0 ? Math.min(15, Math.max(5, Math.ceil(300 / duration))) : 15;

    const args = [
      "-i",
      inputPath,
      "-vf",
      `fps=${targetFps},scale=1920:-1:flags=lanczos`,
      "-gifflags", "-diffcrop",
      "-y",
      outputPath,
    ];
    const ff = spawn(FFMPEG_PATH, args);
    ff.stderr.on("data", (buf) => {
      const line = String(buf);
      const match = line.match(/time=(\d+):(\d+):(\d+\.\d+)/);
      if (match && duration && duration > 0) {
        const [, hh, mm, ss] = match;
        const currentSeconds = Number(hh) * 3600 + Number(mm) * 60 + Number(ss);
        const percent = Math.min(99, Math.round((currentSeconds / duration) * 100));
        progressCb(percent);
      } else if (match) {
        // Если длительность неизвестна, показываем примерный прогресс
        const [, hh, mm, ss] = match;
        const seconds = Number(hh) * 3600 + Number(mm) * 60 + Number(ss);
        const percent = Math.max(1, Math.min(99, Math.floor(seconds / 6)));
        progressCb(percent);
      }
    });
    ff.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error("ffmpeg exited with code " + code));
    });
    ff.on("error", reject);
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
        console.error("Не удалось определить длительность видео:", durError.message);
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
    await pool.query(
      "UPDATE media SET conversion_status='failed', error_message=$1 WHERE id=$2",
      [String(error.message || error), task.id]
    );
    broadcastAdmin("conversion-failed", { mediaId: task.id, error: String(error.message || error) });
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
  const { rows } = await pool.query("SELECT * FROM admins WHERE login = $1", [login]);
  const admin = rows[0];
  if (!admin) return res.status(401).json({ error: "Invalid credentials" });
  const ok = bcrypt.compareSync(password || "", admin.password_hash);
  if (!ok) return res.status(401).json({ error: "Invalid credentials" });
  res.json({ token: signToken(admin), mustChangePassword: admin.must_change_password });
});

app.get("/api/screens", authMiddleware, async (_req, res) => {
  const { rows } = await pool.query(
    "SELECT id, name, host(ip_address) AS ip_address, playlist_id, status, last_heartbeat, created_at FROM screens ORDER BY created_at DESC"
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
  const id = uuidv4();
  const ext = path.extname(req.file.originalname) || ".bin";
  const renamed = `${id}${ext.toLowerCase()}`;
  const absolutePath = path.join(ORIGINAL_DIR, renamed);
  fs.renameSync(req.file.path, absolutePath);
  const originalPath = `/media/original/${renamed}`;

  // Определяем длительность видео перед записью в БД
  let duration = null;
  try {
    duration = await getVideoDuration(absolutePath);
  } catch (durError) {
    console.error("Не удалось определить длительность видео при загрузке:", durError.message);
  }

  await pool.query(
    `INSERT INTO media (id, original_name, mime_type, original_path, file_size, duration_seconds, conversion_status, conversion_progress)
     VALUES ($1, $2, $3, $4, $5, $6, 'pending', 0)`,
    [id, req.file.originalname, req.file.mimetype || "application/octet-stream", originalPath, req.file.size, duration]
  );

  queue.push({ id, originalAbsPath: absolutePath, originalName: req.file.originalname, duration });
  processQueue();
  res.status(201).json({ id, status: "pending", duration });
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
