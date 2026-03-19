const express = require("express");
const sql = require("mssql");
const bcrypt = require("bcrypt");

const app = express();
app.use(express.json());

const config = {
  user: "sa",
  password: "sifresifre123",
  server: "BUSE",
  database: "LifeOS",
  options: {
    instanceName: "SQLEXPRESS",
    encrypt: false,
    trustServerCertificate: true
  }
};

let pool;

// DB connection
async function initDB() {
  try {
    pool = await sql.connect(config);
    console.log("Connected to MSSQL");
  } catch (err) {
    console.error("DB connection FAILED:");
    console.error(err);
  }
}

// TEST
app.get("/test-db", async (req, res) => {
  try {
    const result = await pool.request().query("SELECT GETDATE() AS currentTime");
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ===================== USERS ===================== */

// CREATE USER
app.post("/users", async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: "email and password are required" });
  }

  try {
    const hashedPassword = await bcrypt.hash(password, 10);

    await pool
      .request()
      .input("email", sql.NVarChar, email)
      .input("password", sql.NVarChar, hashedPassword)
      .query(`
        INSERT INTO users (email, password_hash)
        VALUES (@email, @password)
      `);

    res.status(201).json({ message: "User created successfully" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET USERS
app.get("/users", async (req, res) => {
  try {
    const result = await pool.request().query(`
      SELECT id, email, created_at
      FROM users
      ORDER BY id DESC
    `);

    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ===================== HABITS ===================== */

// CREATE HABIT
app.post("/habits", async (req, res) => {
  const { user_id, name, description, frequency_type, target_value } = req.body;

  if (!user_id || !name || !frequency_type) {
    return res.status(400).json({
      error: "user_id, name, and frequency_type are required"
    });
  }

  try {
    await pool
      .request()
      .input("user_id", sql.Int, user_id)
      .input("name", sql.NVarChar, name)
      .input("description", sql.NVarChar, description || null)
      .input("frequency_type", sql.NVarChar, frequency_type)
      .input("target_value", sql.Int, target_value || null)
      .query(`
        INSERT INTO habits (user_id, name, description, frequency_type, target_value)
        VALUES (@user_id, @name, @description, @frequency_type, @target_value)
      `);

    res.status(201).json({ message: "Habit created successfully" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET HABITS
app.get("/habits", async (req, res) => {
  try {
    const result = await pool.request().query(`
      SELECT *
      FROM habits
      ORDER BY id DESC
    `);

    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ===================== HABIT LOGS ===================== */

// CREATE HABIT LOG
app.post("/habit-logs", async (req, res) => {
  const { habit_id, value, log_date } = req.body;

  if (!habit_id || !log_date) {
    return res.status(400).json({
      error: "habit_id and log_date are required"
    });
  }

  try {
    await pool
      .request()
      .input("habit_id", sql.Int, habit_id)
      .input("value", sql.Int, value || null)
      .input("log_date", sql.Date, log_date)
      .query(`
        INSERT INTO habit_logs (habit_id, value, log_date)
        VALUES (@habit_id, @value, @log_date)
      `);

    res.status(201).json({ message: "Habit log created successfully" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET HABIT LOGS
app.get("/habit-logs", async (req, res) => {
  try {
    const result = await pool.request().query(`
      SELECT *
      FROM habit_logs
      ORDER BY id DESC
    `);

    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = 3000;

initDB().then(() => {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
});
app.post("/login", async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: "email and password are required" });
  }

  try {
    const result = await pool
      .request()
      .input("email", sql.NVarChar, email)
      .query(`
        SELECT * FROM users WHERE email = @email
      `);

    const user = result.recordset[0];

    if (!user) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    res.json({ message: "Login successful" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});