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

const formatDate = (value) => {
  if (value instanceof Date) {
    return value.toISOString().slice(0, 10);
  }

  return value?.toString().slice(0, 10);
};

const getMonthlyMoods = async (req, res) => {
  try {
    const userId = req.user.userId;
    const year = Number(req.query.year);
    const month = Number(req.query.month);

    if (!Number.isInteger(year) || !Number.isInteger(month)) {
      return res.status(400).json({
        message: "year and month are required",
      });
    }

    if (year < 2000 || year > 2100 || month < 1 || month > 12) {
      return res.status(400).json({
        message: "invalid year or month",
      });
    }

    const startDate = `${year}-${String(month).padStart(2, "0")}-01`;
    const nextMonth = month === 12 ? 1 : month + 1;
    const nextYear = month === 12 ? year + 1 : year;
    const endDate = `${nextYear}-${String(nextMonth).padStart(2, "0")}-01`;

    const result = await pool.query(
      `
      SELECT mood, log_date
      FROM mood_logs
      WHERE user_id=$1
      AND log_date >= $2
      AND log_date < $3
      ORDER BY log_date ASC
      `,
      [userId, startDate, endDate]
    );

    return res.status(200).json({
      moods: result.rows.map((row) => ({
        mood: row.mood,
        log_date: formatDate(row.log_date),
      })),
    });
  } catch (err) {
    console.error("GET MONTHLY MOODS ERROR:", err);
    return res.status(500).json({
      message: "Server error",
    });
  }
};

module.exports = {
  upsertMood,
  getMood,
  getMonthlyMoods,
};
