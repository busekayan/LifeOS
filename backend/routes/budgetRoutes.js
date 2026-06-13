const express = require("express");
const router = express.Router();

const {
  getAcceptedFriends,
  getPersonalTransactions,
  createPersonalTransaction,
  getBudgetGroups,
  createBudgetGroup,
} = require("../controllers/budgetController");
const verifyToken = require("../middleware/verifyToken");

router.get("/friends", verifyToken, getAcceptedFriends);
router.get("/transactions", verifyToken, getPersonalTransactions);
router.post("/transactions", verifyToken, createPersonalTransaction);
router.get("/groups", verifyToken, getBudgetGroups);
router.post("/groups", verifyToken, createBudgetGroup);

module.exports = router;
