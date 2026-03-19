const express = require("express");
const sql = require("mssql");

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

// DB bağlantısı
async function initDB() {
  try {
    pool = await sql.connect(config);
    console.log("Connected to MSSQL");
  } catch (err) {
    console.error("DB connection FAILED:");
    console.error(err);
  }
}

// TEST endpoint
app.get("/test-db", async (req, res) => {
  if (!pool) {
    return res.status(500).json({ error: "Database not connected" });
  }

  try {
    const result = await pool.request().query("SELECT GETDATE() AS currentTime");
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
// Get all users
app.get("/users", async (req, res) => {
  if (!pool) {
    return res.status(500).json({ error: "Database not connected" });
  }

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

// Get all habits
app.get("/habits", async (req, res) => {
  if (!pool) {
    return res.status(500).json({ error: "Database not connected" });
  }

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

// Get all habit logs
app.get("/habit_logs", async (req, res) => {
  if (!pool) {
    return res.status(500).json({ error: "Database not connected" });
  }

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

// 🔴 CREATE USER ENDPOINT
app.post("/users", async (req, res) => {
  if (!pool) {
    return res.status(500).json({ error: "Database not connected" });
  }

  const { email, password } = req.body;

  try {
    await pool
      .request()
      .input("email", sql.NVarChar, email)
      .input("password", sql.NVarChar, password)
      .query(`
        INSERT INTO users (email, password_hash)
        VALUES (@email, @password)
      `);

    res.status(201).json({ message: "User created successfully" });
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