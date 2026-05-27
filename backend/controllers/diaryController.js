const pool = require("../config/db");

// CREATE / UPDATE (upsert)
const createDiary = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { content, date } = req.body;

    const result = await pool.query(
      `
      INSERT INTO diaries (user_id, content, date)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id, date)
      DO UPDATE SET 
        content = EXCLUDED.content,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
      `,
      [userId, content, date]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error("DIARY ERROR:", err);
    res.status(500).json({
      error: "Diary save error",
      detail: err.message,
    });
  }
};

// GET all diaries
const getDiaries = async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(
      `
      SELECT * 
      FROM diaries 
      WHERE user_id = $1 
      ORDER BY date DESC
      `,
      [userId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("DIARY FETCH ERROR:", err);
    res.status(500).json({ error: "Diary fetch error" });
  }
};

module.exports = {
  createDiary,
  getDiaries,
};