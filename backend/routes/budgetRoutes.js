const express = require("express");
const router = express.Router();

const {
  getAcceptedFriends,
  getBudgetGroups,
  createBudgetGroup,
} = require("../controllers/budgetController");
const verifyToken = require("../middleware/verifyToken");

router.get("/friends", verifyToken, getAcceptedFriends);
router.get("/groups", verifyToken, getBudgetGroups);
router.post("/groups", verifyToken, createBudgetGroup);

module.exports = router;
