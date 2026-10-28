require("./env");
const { Pool, types } = require("pg");
// TIMESTAMP (no tz) = campus time (Asia/Manila). Return as plain "YYYY-MM-DDTHH:MM:SS" strings.
types.setTypeParser(1114, (s) => s.replace(" ", "T").replace(/\.\d+$/, ""));
const ssl = String(process.env.PGSSL).toLowerCase() === "true" ? { rejectUnauthorized: false } : false;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl });
module.exports = { pool, query: (t, p) => pool.query(t, p) };
