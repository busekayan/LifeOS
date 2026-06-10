require("dotenv").config();
const express = require("express");

const pool = require("./config/db");

const userRoutes = require("./routes/userRoutes");
const habitRoutes = require("./routes/habitRoutes");
const habitLogRoutes = require("./routes/habitLogRoutes");
const habitTemplateRoutes = require("./routes/habitTemplateRoutes");
const moodRoutes = require("./routes/moodRoutes"); // ekle
const questionRoutes = require("./routes/questionRoutes");
const diaryRoutes = require("./routes/diaryRoutes");


const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.use("/users", userRoutes);
app.use("/habits", habitRoutes);
app.use("/habit-logs", habitLogRoutes);
app.use("/habit-templates", habitTemplateRoutes);
app.use("/moods", moodRoutes); // ekle
app.use("/questions", questionRoutes); // ekle
app.use("/diaries", diaryRoutes);

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
