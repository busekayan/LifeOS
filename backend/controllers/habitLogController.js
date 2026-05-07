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

module.exports = { toggleHabitLog };