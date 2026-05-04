const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const { toggleHabitLog } = require("../controllers/habitLogController");

router.post("/toggle", verifyToken, toggleHabitLog);

module.exports = router;