const pool = require("../config/db");

const validMoods = [
  "mutlu",
  "sakin",
  "enerjik",
  "uzgun",
  "stresli",
  "yorgun",
];

const upsertMood = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { mood, log_date } = req.body;

    if (!mood || !log_date) {
      return res.status(400).json({
        message: "mood and log_date are required",
      });
    }

    if (!validMoods.includes(mood)) {
      return res.status(400).json({
        message: "invalid mood",
      });
    }

    const result = await pool.query(
      `
      INSERT INTO mood_logs
      (user_id, mood, log_date)
      VALUES ($1,$2,$3)
      ON CONFLICT (user_id, log_date)
      DO UPDATE
      SET
        mood = EXCLUDED.mood,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
      `,
      [userId, mood, log_date]
    );

    return res.status(200).json({
      message: "Mood saved",
      mood: result.rows[0].mood,
      log_date: result.rows[0].log_date,
    });
  } catch (err) {
    console.error("UPSERT MOOD ERROR:", err);
    return res.status(500).json({
      message: "Server error",
    });
  }
};

const getMood = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({
        message: "date is required",
      });
    }

    const result = await pool.query(
      `
      SELECT mood
      FROM mood_logs
      WHERE user_id=$1
      AND log_date=$2
      `,
      [userId, date]
    );

    if (result.rows.length === 0) {
      return res.status(200).json({
        mood: null,
      });
    }

    return res.status(200).json({
      mood: result.rows[0].mood,
    });
  } catch (err) {
    console.error("GET MOOD ERROR:", err);
    return res.status(500).json({
      message: "Server error",
    });
  }
};

module.exports = {
  upsertMood,
  getMood,
};