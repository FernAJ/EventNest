const { Pool } = require("pg");

const pool = new Pool({
  user: "postgres",
  host: "localhost",
  database: "eventnest",
  password: "liger",
  port: 5432
});

module.exports = pool;