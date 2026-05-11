const pool = require("../config/db");

const toggleHabitLog = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { habit_id, log_date } = req.body;

    if (!habit_id || !log_date) {
      return res.status(400).json({
        message: "habit_id and log_date are required",
      });
    }

    // Habit'in goal bilgisini çek
    const habitResult = await pool.query(
      `SELECT target_value FROM habits WHERE id = $1 AND user_id = $2`,
      [habit_id, userId]
    );

    if (habitResult.rows.length === 0) {
      return res.status(404).json({
        message: "Habit not found",
      });
    }

    const { target_value } = habitResult.rows[0];

    // Goal-based habit — toggle değil, value güncelle
    if (target_value !== null) {
      return res.status(400).json({
        message:
          "This habit has a goal. Use PATCH /habit-logs/value to update progress.",
      });
    }

    // Checkbox habit — eski toggle davranışı
    const existingLog = await pool.query(
      `
      SELECT id
      FROM habit_logs
      WHERE habit_id = $1
        AND user_id = $2
        AND log_date = $3
      `,
      [habit_id, userId, log_date]
    );

    if (existingLog.rows.length > 0) {
      await pool.query(
        `
        DELETE FROM habit_logs
        WHERE habit_id = $1
          AND user_id = $2
          AND log_date = $3
        `,
        [habit_id, userId, log_date]
      );

      return res.status(200).json({
        completed: false,
        message: "Habit log removed",
      });
    }

    await pool.query(
      `
      INSERT INTO habit_logs 
        (habit_id, user_id, log_date, value)
      VALUES 
        ($1, $2, $3, $4)
      `,
      [habit_id, userId, log_date, 1]
    );

    return res.status(201).json({
      completed: true,
      message: "Habit log created",
    });
  } catch (err) {
    console.error("TOGGLE HABIT LOG ERROR:", err);

    return res.status(500).json({
      message: "Server error",
    });
  }
};

// Sadece goal-based habitler için — value'yu set eder
const updateHabitLogValue = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { habit_id, log_date, value } = req.body;

    if (!habit_id || !log_date || value === undefined) {
      return res.status(400).json({
        message: "habit_id, log_date and value are required",
      });
    }

    if (!Number.isInteger(value) || value < 0) {
      return res.status(400).json({
        message: "value must be a non-negative integer",
      });
    }

    // Habit'in goal'ü var mı kontrol et
    const habitResult = await pool.query(
      `SELECT target_value FROM habits WHERE id = $1 AND user_id = $2`,
      [habit_id, userId]
    );

    if (habitResult.rows.length === 0) {
      return res.status(404).json({
        message: "Habit not found",
      });
    }

    const { target_value } = habitResult.rows[0];

    if (target_value === null) {
      return res.status(400).json({
        message: "This habit has no goal. Use POST /habit-logs/toggle instead.",
      });
    }

    // value 0 ise log'u sil
    if (value === 0) {
      await pool.query(
        `
        DELETE FROM habit_logs
        WHERE habit_id = $1
          AND user_id = $2
          AND log_date = $3
        `,
        [habit_id, userId, log_date]
      );

      return res.status(200).json({
        completed: false,
        current_value: 0,
        target_value,
        message: "Habit log removed",
      });
    }

    // Upsert — varsa güncelle, yoksa ekle
    await pool.query(
      `
      INSERT INTO habit_logs (habit_id, user_id, log_date, value)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (habit_id, user_id, log_date)
      DO UPDATE SET value = EXCLUDED.value
      `,
      [habit_id, userId, log_date, value]
    );

    const completed = value >= target_value;

    return res.status(200).json({
      completed,
      current_value: value,
      target_value,
      message: completed ? "Goal reached!" : "Progress updated",
    });
  } catch (err) {
    console.error("UPDATE HABIT LOG VALUE ERROR:", err);

    return res.status(500).json({
      message: "Server error",
    });
  }
};

module.exports = { toggleHabitLog, updateHabitLogValue };