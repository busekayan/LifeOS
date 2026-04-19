require("dotenv").config();
const express = require("express");
const userRoutes = require("./routes/userRoutes");

const app = express();
const PORT = 3000;

app.use(express.json());

// /users ile başlayan istekleri userRoutes'a yönlendiriyoruz
app.use("/users", userRoutes);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});