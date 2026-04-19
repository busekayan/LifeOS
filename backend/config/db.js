const sql = require("mssql/msnodesqlv8");

const config = {
  server: "BUSE\\SQLEXPRESS",
  database: "LifeOS",
  driver: "msnodesqlv8",
  options: {
    trustedConnection: true,
    trustServerCertificate: true,
  },
};

const poolPromise = new sql.ConnectionPool(config)
  .connect()
  .then((pool) => {
    console.log("Connected to MSSQL with Windows Authentication");
    return pool;
  })
  .catch((err) => {
    console.error("DB connection error:", err);
    return null;
  });

module.exports = {
  sql,
  poolPromise,
};