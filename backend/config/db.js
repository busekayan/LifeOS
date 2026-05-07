const { Pool } = require("pg");
require("dotenv").config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
  },
});

async function connectDB() {
  try {
    await pool.query("SELECT NOW()");
    console.log("Connected to PostgreSQL");
  } catch (err) {
    console.error("DB connection error:", err);
  }
}

module.exports = pool;