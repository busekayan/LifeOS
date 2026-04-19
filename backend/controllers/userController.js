const jwt = require("jsonwebtoken");
const { sql, poolPromise } = require("../config/db");
const bcrypt = require("bcrypt");

const registerUser = async (req, res) => {
  let { firstName, lastName, email, password } = req.body;

  try {
    console.log("REQ BODY:", req.body);

    firstName = firstName?.trim();
    lastName = lastName?.trim();
    email = email?.trim().toLowerCase();
    password = password?.trim();

    if (!firstName || !lastName || !email || !password) {
      return res.status(400).json({
        message: "Tüm alanlar zorunlu",
      });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        message: "Geçerli bir email adresi giriniz",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        message: "Şifre en az 6 karakter olmalıdır",
      });
    }

    const pool = await poolPromise;

    if (!pool) {
      return res.status(500).json({
        message: "Veritabanı bağlantısı kurulamadı",
      });
    }

    const existingUser = await pool
      .request()
      .input("email", sql.NVarChar, email)
      .query("SELECT id FROM users WHERE email = @email");

    if (existingUser.recordset.length > 0) {
      return res.status(400).json({
        message: "Bu email zaten kayıtlı",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    await pool
      .request()
      .input("firstName", sql.NVarChar, firstName)
      .input("lastName", sql.NVarChar, lastName)
      .input("email", sql.NVarChar, email)
      .input("passwordHash", sql.NVarChar, hashedPassword)
      .query(`
        INSERT INTO users (first_name, last_name, email, password_hash)
        VALUES (@firstName, @lastName, @email, @passwordHash)
      `);

    return res.status(201).json({
      message: "Kullanıcı oluşturuldu",
    });
  } catch (err) {
    console.error("REGISTER ERROR:", err);

    return res.status(500).json({
      message: "Server hatası",
    });
  }
};

const loginUser = async (req, res) => {
  let { email, password } = req.body;

  try {
    console.log("LOGIN REQ BODY:", req.body);

    email = email?.trim().toLowerCase();
    password = password?.trim();

    if (!email || !password) {
      return res.status(400).json({
        message: "Email ve şifre zorunludur",
      });
    }

    const pool = await poolPromise;

    if (!pool) {
      return res.status(500).json({
        message: "Veritabanı bağlantısı kurulamadı",
      });
    }

    const userResult = await pool
      .request()
      .input("email", sql.NVarChar, email)
      .query(`
        SELECT id, first_name, last_name, email, password_hash
        FROM users
        WHERE email = @email
      `);

    if (userResult.recordset.length === 0) {
      return res.status(400).json({
        message: "Email veya şifre hatalı",
      });
    }

    const user = userResult.recordset[0];

    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      return res.status(400).json({
        message: "Email veya şifre hatalı",
      });
    }

    // JWT token oluşturuyoruz
    const token = jwt.sign(
      {
        userId: user.id,
        email: user.email,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: process.env.JWT_EXPIRES_IN || "1d",
      }
    );

    return res.status(200).json({
      message: "Giriş başarılı",
      token,
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
      },
    });
  } catch (err) {
    console.error("LOGIN ERROR:", err);

    return res.status(500).json({
      message: "Server hatası",
    });
  }
};

module.exports = { registerUser, loginUser };