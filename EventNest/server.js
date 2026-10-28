require("./src/env");
const path = require("path");
const express = require("express");
const routes = require("./src/routes");

const app = express();
app.set("trust proxy", 1); // Render sits behind a proxy
app.use(express.json({ limit: "100kb" }));
app.use("/api", routes);
app.use("/api", (req, res) => res.status(404).json({ error: "Not found." }));
app.use(express.static(path.join(__dirname, "public")));

// Central error handler: translate PostgreSQL constraint errors into clean messages.
app.use((err, req, res, next) => {
  const map = {
    "23P01": [409, "That venue is already booked by an approved event at this time."],
    "23505": [409, "That record already exists."],
    "23503": [400, "Referenced record does not exist."],
    "23514": [400, "Invalid data (check that the end time is after the start time)."],
    "22P02": [400, "Invalid input."],
    "22007": [400, "Invalid date/time."],
  };
  const m = map[err.code];
  if (m) return res.status(m[0]).json({ error: m[1] });
  if (err.type === "entity.parse.failed") return res.status(400).json({ error: "Malformed JSON." });
  console.error(err);
  res.status(500).json({ error: "Server error." });
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`EventNest running on http://localhost:${port}`));
