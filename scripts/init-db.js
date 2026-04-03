const fs = require("fs");
const path = require("path");
const { Pool } = require("pg");
const { v4: uuidv4 } = require("uuid");
const bcrypt = require("bcryptjs");
require("dotenv").config();

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const sql = fs.readFileSync(path.join(__dirname, "..", "database", "init.sql"), "utf8");
  await pool.query(sql);

  const login = process.env.ADMIN_LOGIN || "admin";
  let passwordHash = process.env.ADMIN_PASSWORD_HASH;
  if (!passwordHash && process.env.ADMIN_PASSWORD) {
    passwordHash = bcrypt.hashSync(process.env.ADMIN_PASSWORD, 12);
  }
  if (!passwordHash) {
    passwordHash = bcrypt.hashSync("admin", 12);
  }

  const exists = await pool.query("SELECT id FROM admins WHERE login = $1", [login]);
  if (!exists.rowCount) {
    await pool.query(
      "INSERT INTO admins (id, login, password_hash, must_change_password) VALUES ($1, $2, $3, true)",
      [uuidv4(), login, passwordHash]
    );
    console.log("Admin user created:", login);
  } else {
    console.log("Admin user already exists:", login);
  }

  await pool.end();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
