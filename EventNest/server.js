
const express = require("express");
const pool = require("./db");

const app = express();
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

// Start the server.
app.listen(PORT, () => {
  console.log(`EventNest server running on port ${PORT}`);
});
