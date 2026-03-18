const sql = require("mssql");

const config = {
  user: "sa",
  password: "your_password",
  server: "localhost",
  database: "LifeOS",
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

async function connectDB() {
  try {
    await sql.connect(config);
    console.log("Connected to MSSQL");
  } catch (err) {
    console.error("DB connection error:", err);
  }
}

module.exports = { connectDB, sql };