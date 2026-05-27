const pool = require("../config/db");

const getDailyQuestions = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT *
      FROM daily_questions
      ORDER BY RANDOM()
      LIMIT 3
    `);

    res.json({
      questions: result.rows
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      message: "Sorular alınamadı"
    });
  }
};

module.exports = {
  getDailyQuestions,
};