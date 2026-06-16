const express = require("express");

const userRoutes = require("./routes/userRoutes");
const habitRoutes = require("./routes/habitRoutes");
const habitLogRoutes = require("./routes/habitLogRoutes");
const habitTemplateRoutes = require("./routes/habitTemplateRoutes");
const budgetRoutes = require("./routes/budgetRoutes");
const moodRoutes = require("./routes/moodRoutes");
const questionRoutes = require("./routes/questionRoutes");
const diaryRoutes = require("./routes/diaryRoutes");
const docsRoutes = require("./routes/docsRoutes");

const app = express();

app.use(express.json());

app.use("/", docsRoutes);
app.use("/users", userRoutes);
app.use("/habits", habitRoutes);
app.use("/habit-logs", habitLogRoutes);
app.use("/habit-templates", habitTemplateRoutes);
app.use("/budget", budgetRoutes);
app.use("/moods", moodRoutes);
app.use("/questions", questionRoutes);
app.use("/diaries", diaryRoutes);

module.exports = app;
