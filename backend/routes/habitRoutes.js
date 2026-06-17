const express = require("express");
const router = express.Router();

const {
  createHabit,
  getHabits,
  getHabitSummary,
  deleteHabit,
} = require("../controllers/habitController");
const verifyToken = require("../middleware/verifyToken");

router.post("/", verifyToken, createHabit);
router.get("/summary", verifyToken, getHabitSummary);
router.get("/", verifyToken, getHabits);
router.delete("/:id", verifyToken, deleteHabit);

module.exports = router;
