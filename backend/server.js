const express = require("express");
const sql = require("mssql");

const app = express();
app.use(express.json());

const config = {
  user: "sa",
  password: "sifresifre123",
  server: "BUSE\\SQLEXPRESS",
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
    console.error(err); // 🔴 BURASI ÇOK ÖNEMLİ
  }
}

// Test endpoint
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

const PORT = 3000;

initDB().then(() => {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
});