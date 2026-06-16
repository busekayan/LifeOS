const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const {
  upsertMood,
  getMood,
  getMonthlyMoods,
} = require("../controllers/moodController");

router.get("/month", verifyToken, getMonthlyMoods);
router.get("/", verifyToken, getMood);
router.post("/", verifyToken, upsertMood);

module.exports = router;
