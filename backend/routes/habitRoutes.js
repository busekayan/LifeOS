const express = require("express");
const router = express.Router();

const { createHabit, getHabits } = require("../controllers/habitController");
const verifyToken = require("../middleware/verifyToken");

router.post("/", verifyToken, createHabit);
router.get("/", verifyToken, getHabits);

module.exports = router;