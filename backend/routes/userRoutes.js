const express = require("express");
const router = express.Router();
const { registerUser, loginUser } = require("../controllers/userController");
const verifyToken = require("../middleware/verifyToken");

// Kayıt olma endpointi
router.post("/register", registerUser);

// Giriş yapma endpointi
router.post("/login", loginUser);

// Test için korumalı route
router.get("/profile", verifyToken, (req, res) => {
  return res.status(200).json({
    message: "Protected route accessed successfully",
    user: req.user,
  });
});

module.exports = router;