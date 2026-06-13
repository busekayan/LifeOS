const express = require("express");
const router = express.Router();

const {
  getHabitTemplates,
  addHabitTemplate,
  deleteHabitTemplateGroup,
} = require("../controllers/habitTemplateController");
const verifyToken = require("../middleware/verifyToken");

router.get("/", verifyToken, getHabitTemplates);
router.post("/:id/add", verifyToken, addHabitTemplate);
router.delete("/:id", verifyToken, deleteHabitTemplateGroup);

module.exports = router;
