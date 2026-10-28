// Usage: npm run db:import   (runs database/eventnest.sql against DATABASE_URL)
require("../src/env");
const fs = require("fs"), path = require("path");
const { pool } = require("../src/db");
(async () => {
  const sql = fs.readFileSync(path.join(__dirname, "..", "database", "eventnest.sql"), "utf8");
  await pool.query(sql);
  console.log("Database imported: tables created and sample data loaded.");
  await pool.end();
})().catch((e) => { console.error("Import failed:", e.message); process.exit(1); });
