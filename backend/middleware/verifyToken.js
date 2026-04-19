const jwt = require("jsonwebtoken");

const verifyToken = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    // Header yoksa veya Bearer formatında değilse hata dön
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        message: "Access denied. No token provided."
      });
    }

    // Bearer TOKEN kısmından token'ı al
    const token = authHeader.split(" ")[1];

    // Token'ı doğrula
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Çözülen kullanıcı bilgisini request'e ekle
    req.user = decoded;

    next();
  } catch (error) {
    return res.status(401).json({
      message: "Invalid or expired token"
    });
  }
};

module.exports = verifyToken;