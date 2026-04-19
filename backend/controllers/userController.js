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
    const accessToken = jwt.sign(
      {
        userId: user.id,
        email: user.email,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "30m",
      }
    );

    const refreshToken = jwt.sign(
      {
        userId: user.id,
      },
      process.env.JWT_REFRESH_SECRET,
      {
        expiresIn: "30d",
      }
    );

    const refreshTokenExpiresAt = new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000
    );

    await pool
      .request()
      .input("userId", sql.Int, user.id)
      .input("token", sql.NVarChar, refreshToken)
      .input("expiresAt", sql.DateTime, refreshTokenExpiresAt)
      .query(`
        INSERT INTO refresh_tokens (user_id, token, expires_at)
        VALUES (@userId, @token, @expiresAt)
      `);

    return res.status(200).json({
      message: "Giriş başarılı",
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
      },
    });
    // // JWT token oluşturuyoruz

  } catch (err) {
    console.error("LOGIN ERROR:", err);

    return res.status(500).json({
      message: "Server hatası",
    });
  }
};
const refreshTokenUser = async (req, res) => {
  const { refreshToken } = req.body;

  try {
    if (!refreshToken) {
      return res.status(401).json({
        message: "Refresh token gerekli",
      });
    }

    const decoded = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET
    );

    const pool = await poolPromise;

    if (!pool) {
      return res.status(500).json({
        message: "Veritabanı bağlantısı kurulamadı",
      });
    }

    const tokenResult = await pool
      .request()
      .input("token", sql.NVarChar, refreshToken)
      .query(`
        SELECT id, user_id, token, expires_at, is_revoked
        FROM refresh_tokens
        WHERE token = @token
      `);

    if (tokenResult.recordset.length === 0) {
      return res.status(403).json({
        message: "Geçersiz refresh token",
      });
    }

    const storedToken = tokenResult.recordset[0];

    if (storedToken.is_revoked) {
      return res.status(403).json({
        message: "Refresh token iptal edilmiş",
      });
    }

    if (new Date(storedToken.expires_at) < new Date()) {
      return res.status(403).json({
        message: "Refresh token süresi dolmuş",
      });
    }

    const newAccessToken = jwt.sign(
      {
        userId: decoded.userId,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "30m",
      }
    );

    return res.status(200).json({
      message: "Yeni access token oluşturuldu",
      accessToken: newAccessToken,
    });
  } catch (err) {
    console.error("REFRESH TOKEN ERROR:", err);

    return res.status(403).json({
      message: "Geçersiz veya süresi dolmuş refresh token",
    });
  }
};
const logoutUser = async (req, res) => {
  const { refreshToken } = req.body;

  try {
    if (!refreshToken) {
      return res.status(400).json({
        message: "Refresh token gerekli",
      });
    }

    const pool = await poolPromise;

    if (!pool) {
      return res.status(500).json({
        message: "Veritabanı bağlantısı kurulamadı",
      });
    }

    await pool
      .request()
      .input("token", sql.NVarChar, refreshToken)
      .query(`
        UPDATE refresh_tokens
        SET is_revoked = 1
        WHERE token = @token
      `);

    return res.status(200).json({
      message: "Çıkış başarılı",
    });
  } catch (err) {
    console.error("LOGOUT ERROR:", err);

    return res.status(500).json({
      message: "Server hatası",
    });
  }
};
module.exports = { registerUser, loginUser, refreshTokenUser, logoutUser };