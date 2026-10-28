// Tiny .env loader (no dependency). Real environment variables always win.
const fs = require("fs");
const path = require("path");
const file = path.join(__dirname, "..", ".env");
if (fs.existsSync(file)) {
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
