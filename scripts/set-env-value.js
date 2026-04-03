const fs = require("fs");
const path = require("path");

const envPath = path.join(__dirname, "..", ".env");
const key = process.argv[2];
const value = process.argv[3];
if (!key || value === undefined) {
  console.error("Usage: node set-env-value.js KEY value");
  process.exit(1);
}
let lines = [];
if (fs.existsSync(envPath)) {
  lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
}
let found = false;
const out = lines.map((line) => {
  if (!line || line.startsWith("#")) return line;
  const i = line.indexOf("=");
  if (i === -1) return line;
  const k = line.slice(0, i).trim();
  if (k === key) {
    found = true;
    return `${key}=${value}`;
  }
  return line;
});
if (!found) out.push(`${key}=${value}`);
fs.writeFileSync(envPath, out.join("\n") + "\n", "utf8");
console.log("Updated", key, "in .env");
