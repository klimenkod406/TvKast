/**
 * Подключение к кластеру PostgreSQL под суперпользователем, создание БД и роли приложения.
 * Пароль суперпользователя передаётся через POSTGRES_SUPERUSER_PASSWORD (не в URL).
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { Client } = require("pg");

const ROOT = path.join(__dirname, "..");
const ENV_PATH = path.join(ROOT, ".env");
const EXAMPLE_PATH = path.join(ROOT, ".env.example");

function safeIdent(name) {
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name)) {
    throw new Error("Invalid database/user name");
  }
  return name;
}

function mergeEnvFile(updates) {
  let content = "";
  if (fs.existsSync(ENV_PATH)) {
    content = fs.readFileSync(ENV_PATH, "utf8");
  } else if (fs.existsSync(EXAMPLE_PATH)) {
    content = fs.readFileSync(EXAMPLE_PATH, "utf8");
  }
  const lines = content.split(/\r?\n/).filter(Boolean);
  const map = new Map();
  for (const line of lines) {
    const idx = line.indexOf("=");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    map.set(key, line.slice(idx + 1));
  }
  for (const [k, v] of Object.entries(updates)) {
    map.set(k, String(v));
  }
  map.delete("ADMIN_PASSWORD_HASH");
  const out = [...map.entries()].map(([k, v]) => `${k}=${v}`).join("\n") + "\n";
  fs.writeFileSync(ENV_PATH, out, "utf8");
  console.log("Updated", ENV_PATH);
}

async function main() {
  const host = process.env.POSTGRES_HOST || "localhost";
  const port = Number(process.env.POSTGRES_PORT || 5432);
  const superUser = process.env.POSTGRES_SUPERUSER || "postgres";
  const superPassword = process.env.POSTGRES_SUPERUSER_PASSWORD || "";

  const dbName = safeIdent(process.env.DS_DB_NAME || "digitalsignage_db");
  const appUser = safeIdent(process.env.DS_DB_USER || "digitalsignage");
  let appPassword = process.env.DS_DB_PASSWORD || crypto.randomBytes(18).toString("base64url");

  const admin = new Client({
    host,
    port,
    user: superUser,
    password: superPassword === "" ? undefined : superPassword,
    database: "postgres",
  });

  await admin.connect();

  const roleExists = await admin.query("SELECT 1 FROM pg_roles WHERE rolname = $1", [appUser]);
  if (!roleExists.rows.length) {
    await admin.query(`CREATE ROLE ${appUser} WITH LOGIN PASSWORD $1`, [appPassword]);
    console.log("Created role", appUser);
  } else {
    await admin.query(`ALTER ROLE ${appUser} WITH PASSWORD $1`, [appPassword]);
    console.log("Updated password for role", appUser);
  }

  const dbExists = await admin.query("SELECT 1 FROM pg_database WHERE datname = $1", [dbName]);
  if (!dbExists.rows.length) {
    await admin.query(`CREATE DATABASE ${dbName} OWNER ${appUser}`);
    console.log("Created database", dbName);
  } else {
    console.log("Database already exists:", dbName);
  }

  await admin.query(`GRANT ALL PRIVILEGES ON DATABASE ${dbName} TO ${appUser}`);

  const dbAdmin = new Client({
    host,
    port,
    user: superUser,
    password: superPassword === "" ? undefined : superPassword,
    database: dbName,
  });
  await dbAdmin.connect();
  await dbAdmin.query(`GRANT CREATE ON SCHEMA public TO ${appUser}`);
  await dbAdmin.query(`GRANT USAGE ON SCHEMA public TO ${appUser}`);
  await dbAdmin.end();

  await admin.end();

  const encUser = encodeURIComponent(appUser);
  const encPass = encodeURIComponent(appPassword);
  const databaseUrl = `postgresql://${encUser}:${encPass}@${host}:${port}/${dbName}`;

  const jwtSecret = process.env.JWT_SECRET || crypto.randomBytes(32).toString("hex");
  const ffmpegPath = process.env.FFMPEG_PATH || "ffmpeg";

  mergeEnvFile({
    PORT: process.env.PORT || "3000",
    DATABASE_URL: databaseUrl,
    JWT_SECRET: jwtSecret,
    ADMIN_LOGIN: process.env.ADMIN_LOGIN || "admin",
    FFMPEG_PATH: ffmpegPath,
    USE_VIDEO_IF_SUPPORTED: process.env.USE_VIDEO_IF_SUPPORTED || "false",
  });

  console.log("DATABASE_URL configured for user", appUser);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
