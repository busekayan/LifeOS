const express = require("express");
const router = express.Router();
const { getDailyQuestions } = require("../controllers/questionController");
const authenticateToken = require("../middleware/verifyToken");

router.get("/daily-questions", authenticateToken, getDailyQuestions);

module.exports = router;