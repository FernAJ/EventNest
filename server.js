
const express = require("express");
const pool = require("./db");

const app = express();
app.get("/route-check", (req, res) => {
  res.send("Route check works!");
});
const PORT = process.env.PORT || 3000;

// Allows the backend to receive JSON data.
app.use(express.json());

// A simple test route.
app.get("/", (req, res) => {
  res.json({
    message: "EventNest backend is running!",
    status: "success"
  });
});

// Test the PostgreSQL database connection.
app.get("/db-test", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");

    res.json({
      message: "Connected to PostgreSQL successfully!",
      time: result.rows[0].now
    });
  } catch (error) {
    console.error("Database connection error:", error.message);

    res.status(500).json({
      message: "Database connection failed."
    });
  }
});

 // Get all events from the database.
app.get("/events", async (req, res) => {
  console.log(">>> /events route was reached!");
  try {
    const result = await pool.query(
      "SELECT * FROM events ORDER BY date ASC, start_time ASC"
    );

    res.json(result.rows);
  } catch (error) {
    console.error("Error fetching events:", error.message);

    res.status(500).json({
      message: "Failed to retrieve events."
    });
  }
});

console.log("Registered routes:");
app._router?.stack?.forEach((layer) => {
  if (layer.route) {
    console.log(
      Object.keys(layer.route.methods).join(",").toUpperCase(),
      layer.route.path
    );
  }
});

// Start the server.
app.listen(PORT, () => {
  console.log(`EventNest server running on port ${PORT}`);
});
