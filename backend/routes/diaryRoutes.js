const express = require("express");
const router = express.Router();

const {
  createDiary,
  getDiaries
} = require("../controllers/diaryController");

const authenticateToken = require("../middleware/verifyToken");

router.post("/", authenticateToken, createDiary);
router.get("/", authenticateToken, getDiaries);

module.exports = router;