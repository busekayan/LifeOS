const express = require("express");
const router = express.Router();

const {
  getAcceptedFriends,
  getIncomingFriendInvitations,
  createFriendInvitation,
  respondToFriendInvitation,
  getPersonalTransactions,
  createPersonalTransaction,
  getBudgetGroups,
  createBudgetGroup,
  createSharedExpense,
} = require("../controllers/budgetController");
const verifyToken = require("../middleware/verifyToken");

router.get("/friends", verifyToken, getAcceptedFriends);
router.get("/friend-invitations", verifyToken, getIncomingFriendInvitations);
router.post("/friend-invitations", verifyToken, createFriendInvitation);
router.post(
  "/friend-invitations/:id/respond",
  verifyToken,
  respondToFriendInvitation
);
router.get("/transactions", verifyToken, getPersonalTransactions);
router.post("/transactions", verifyToken, createPersonalTransaction);
router.get("/groups", verifyToken, getBudgetGroups);
router.post("/groups", verifyToken, createBudgetGroup);
router.post("/groups/:groupId/expenses", verifyToken, createSharedExpense);

module.exports = router;
