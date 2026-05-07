require("dotenv").config();
const express = require("express");

const pool = require("./config/db");

const userRoutes = require("./routes/userRoutes");
const habitRoutes = require("./routes/habitRoutes");
const habitLogRoutes = require("./routes/habitLogRoutes");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.use("/users", userRoutes);
app.use("/habits", habitRoutes);
app.use("/habit-logs", habitLogRoutes);

pool
  .query("SELECT NOW()")
  .then(() => {
    console.log("Connected to PostgreSQL");

    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("DB connection error:", err);
  });