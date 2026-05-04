const express = require("express");
const router = express.Router();

const {
  registerUser,
  loginUser,
  refreshTokenUser,
  logoutUser,
  getMe,
} = require("../controllers/userController");

const verifyToken = require("../middleware/verifyToken");

router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/refresh", refreshTokenUser);
router.post("/logout", logoutUser);

// Kullanıcının kendi bilgisini dönen endpoint
router.get("/me", verifyToken, getMe);

module.exports = router;