const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const { toggleHabitLog , updateHabitLogValue} = require("../controllers/habitLogController");

router.post("/toggle", verifyToken, toggleHabitLog);
router.patch("/value", verifyToken, updateHabitLogValue);  // yeni


module.exports = router;