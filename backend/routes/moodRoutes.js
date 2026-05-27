const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const { upsertMood, getMood } = require("../controllers/moodController");

router.get("/", verifyToken, getMood);
router.post("/", verifyToken, upsertMood);

module.exports = router;