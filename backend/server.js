require("dotenv").config();
const express = require("express");
const userRoutes = require("./routes/userRoutes");
const habitRoutes = require("./routes/habitRoutes");
const habitLogRoutes = require("./routes/habitLogRoutes");

const app = express();
const PORT = 3000;

app.use(express.json());


app.use("/users", userRoutes);
app.use("/habits", habitRoutes);
app.use("/habit-logs", habitLogRoutes);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});